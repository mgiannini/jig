//
// Copyright (c) 2026, Novant LLC
// Licensed under the MIT License
//
// History:
//   27 Oct 2026  Andy Frank  Creation
//

using build
using concurrent

*************************************************************************
** Builder
*************************************************************************

** Builder spawns 'fan <build.fan> compile', parses its output, and
** renders one line per pod with the same live status bar as Runner.
** The running pod stays pinned above the bar with its current build
** step to the right in dim text.
**
** Build output is line based: a top level '<target> [<pod>]' line
** starts a pod, indented lines are progress steps, and any other
** top level line is an error or warning for the current pod, until
** 'BUILD SUCCESS' or 'BUILD FAILED'.  Each row is tagged with its
** target; with several targets a group runs each target across all
** pods in turn, so each pod gets one row per target.
class Builder
{
  ** Entry point for 'jig build'; each arg is a pod under the root
  ** script or a build script path; with no args build the root
  ** script.  Runs 'compile' unless one of these picks the target:
  ** 'clean' only cleans; 'full' cleans, compiles, and tests the
  ** built pods once all compile; 'target' runs that build target.
  static Int main(Str[] args, Bool quiet, Bool clean, Bool full, Str? target := null)
  {
    scripts := BuildScript[,]
    try
    {
      BuildScript? root
      args.each |arg|
      {
        if (arg.endsWith(".fan")) { scripts.add(load(File.os(arg).normalize)); return }
        // root build script may not include the pod, so fall back to
        // searching the current repo's src/
        if (root == null) { f := findRoot(false); if (f != null) root = load(f) }
        pod := (root == null ? null : findPod(root, arg)) ?: searchPod(repoRoot(File.os(".").normalize), arg)
        scripts.add(pod ?: throw ArgErr("Unknown pod: $arg"))
      }
      if (scripts.isEmpty) scripts.add(load(findRoot))

      // check target up front so a typo fails before anything runs
      if (target != null)
        scripts.each |s|
        {
          if (s.target(target, false) == null)
            throw ArgErr("Unknown target '$target' for ${s.scriptFile.osPath}; " +
              "targets: " + s.targets.map |m| { m.name }.join(", "))
        }
    }
    catch (ArgErr e) { echo("ERR: $e.msg"); return 1 }

    // rewriting the pod file jig is running from breaks class loading
    pods := scripts.map |s| { JigBuild.podNames(s) }.flatten
    self := Builder#.pod.name
    if (pods.contains(self) && Env.cur.findPodFile(self)?.normalize == (Env.cur.workDir + `lib/fan/${self}.pod`).normalize)
    {
      echo("ERR: cannot rebuild running ${self}.pod; use 'fan build.fan' or an installed jig")
      return 1
    }

    targets := ["compile"]
    if (full) targets = ["clean", "compile"]
    else if (clean) targets = ["clean"]
    else if (target != null) targets = [target]
    code := Builder(scripts.map |s->File| { s.scriptFile }, pods, targets, quiet).run
    if (code != 0 || !full) return code
    return test(pods, quiet)
  }

  ** Run tests for each of 'pods' that has any, after a full build.
  private static Int test(Str[] pods, Bool quiet)
  {
    tests := Str[,]
    targets := Str[,]
    pods.each |name|
    {
      pod := Pod.find(name, false)
      if (pod == null) return
      t := Resolver.podTests(pod)
      if (t.isEmpty) return
      targets.add(name)
      tests.addAll(t)
    }
    if (tests.isEmpty) { echo("No tests found"); return 0 }
    return Runner(targets, tests, quiet).run
  }

  ** Root build script: './build.fan', else '<workDir>/src/build.fan';
  ** if neither exists return null or throw ArgErr based on 'checked'.
  static File? findRoot(Bool checked := true)
  {
    cwd := File.os(".").normalize
    f := cwd + `build.fan`
    if (f.exists) return f
    f = Env.cur.workDir + `src/build.fan`
    if (f.exists) return f
    if (!checked) return null
    throw ArgErr("no build.fan in ${cwd.osPath} or ${f.parent.osPath}")
  }

  ** Compile and construct build script, as 'build::Main' does.
  static BuildScript load(File file)
  {
    if (!file.exists) throw ArgErr("File not found: $file.osPath")
    Obj? obj
    try obj = Env.cur.compileScript(file).make
    catch (Err e) throw ArgErr("Cannot load $file.osPath: $e.msg")
    return obj as BuildScript ?: throw ArgErr("Not a BuildScript: $file.osPath")
  }

  ** Root of the repo holding 'dir': the nearest ancestor with a
  ** '.git' dir or file, else 'dir' itself.
  static File repoRoot(File dir)
  {
    for (File? d := dir; d != null; d = d.parent)
      if (d.plus(`.git`, false).exists) return d
    return dir
  }

  ** Search the 'src/' tree of repo 'root' for a pod named 'name' by
  ** its directory: a dir named 'name' whose 'build.fan' builds that
  ** pod.  Returns null if none or there is no 'src/', and throws if
  ** more than one.
  static BuildPod? searchPod(File root, Str name)
  {
    src := root + `src/`
    if (!src.exists) return null
    found := BuildPod[,]
    podDirs(src, name).each |dir|
    {
      pod := load(dir + `build.fan`) as BuildPod
      if (pod?.podName == name) found.add(pod)
    }
    if (found.size > 1)
      throw ArgErr("Ambiguous pod '$name': " + found.map |p| { p.scriptFile.osPath }.join(", "))
    return found.first
  }

  ** Dirs under 'dir' named 'name' with a 'build.fan'; skips hidden
  ** dirs and 'node_modules'.
  internal static File[] podDirs(File dir, Str name, File[] acc := File[,])
  {
    dir.listDirs.each |d|
    {
      if (d.name.startsWith(".") || d.name == "node_modules") return
      if (d.name == name && (d + `build.fan`).exists) acc.add(d)
      podDirs(d, name, acc)
    }
    return acc
  }

  ** Find BuildPod for 'name' anywhere under 'script', or null.
  static BuildPod? findPod(BuildScript script, Str name)
  {
    if (script is BuildPod) return ((BuildPod)script).podName == name ? script : null
    if (script is BuildGroup)
      return ((BuildGroup)script).children.eachWhile |c| { findPod(c, name) }
    return null
  }

  ** Create builder to run 'targets' on each of 'scripts', which
  ** together are expected to build 'pods'.
  new make(File[] scripts, Str[] pods, Str[] targets := ["compile"], Bool quiet := false,
           Bool? tty := null, OutStream out := Env.cur.out, File? cwd := null)
  {
    this.cwd     = cwd ?: File.os(".").normalize
    this.scripts = scripts
    this.targets = targets
    this.podCount = pods.size
    this.total    = pods.size * targets.size
    pods.each |p| { nameWidth = nameWidth.max(p.size) }
    targets.each |t| { targetWidth = targetWidth.max(t.size) }
    this.quiet  = quiet
    this.tty    = tty ?: Term.isTty
    this.width  = this.tty ? Term.width : 80
    this.out    = out
  }

  ** Run build and return exit code.
  Int run()
  {
    // blank line spaces results off from the command line
    out.printLine
    pool := startTicker
    exit := 0
    scripts.eachWhile |script|
    {
      done.val = false
      exit = Term.exec(Term.fan.add(script.osPath).addAll(targets), |line| { parseLine(line) }) |->Bool| { done.val }
      if (!done.val) endPod(exit == 0)
      return exit != 0 || failedPod != null ? true : null
    }

    // stop ticker before writing summary
    running.val = false
    pool?.stop?.join(1sec)
    if (tty) out.print(erase).flush
    return summary(exit)
  }

  ** Redraw every 100ms so elapsed time moves during long steps.
  private ActorPool? startTicker()
  {
    if (!tty) return null
    pool := ActorPool { it.name = "jigTicker"; it.maxThreads = 1 }
    self := Unsafe(this)
    flag := this.running
    Actor(pool) |->Obj?|
    {
      while (flag.val) { Actor.sleep(100ms); ((Builder)self.val).redraw }
      return null
    }.send(null)
    return pool
  }

//////////////////////////////////////////////////////////////////////////
// Parsing
//////////////////////////////////////////////////////////////////////////

  ** Parse next line of build output, without trailing newline.
  internal Void parseLine(Str line)
  {
    if (done.val) return

    if (line.startsWith("BUILD SUCCESS")) { endPod(true);  done.val = true; return }
    if (line.startsWith("BUILD FAILED"))  { endPod(false); done.val = true; return }

    // '<target> [<pod>]' starts a row for that pod and target
    m := headerRegex.matcher(line)
    if (m.matches)
    {
      pod := m.group(2)
      target := m.group(1)
      if (pod != curPod || target != curTarget) { endPod(true); startPod(pod, target) }
      step = null
      redraw
      return
    }

    if (line.trim.isEmpty) return

    // top level lines are errors or warnings; once one is seen keep
    // indented lines too so traces and multi-line messages stay whole
    indented := line.startsWith(" ")
    if (!indented || !msgs.isEmpty) msgs.add(line)
    if (!indented && line.contains(": WARN ")) warns++
    if (indented) { step = line.trim; checkWritePod(step) }
    redraw
  }

  ** Record output dir from 'WritePod [file:/.../lib/fan/acme.pod]'
  ** for the summary.
  private Void checkWritePod(Str step)
  {
    if (!step.startsWith("WritePod [file:") || !step.endsWith("]")) return
    try
    {
      // keep the 'file:' scheme so 'relPath' can match it to cwd
      dir := File(step["WritePod [".size..-2].toUri).parent
      if (dir != null && !outDirs.contains(dir)) outDirs.add(dir)
    }
    catch (Err e) {}
  }

  private Void startPod(Str pod, Str target)
  {
    curPod    = pod
    curTarget = target
    podStart  = now
    step     = null
  }

  ** Finish current pod; if no pod started yet only failures and
  ** stray output are kept.
  private Void endPod(Bool ok)
  {
    pod := curPod
    if (pod == null)
    {
      if (!ok) failedPod = failedPod ?: ""
      if (!ok || !msgs.isEmpty) details.add(msgs.dup)
      msgs.clear
      return
    }

    target := curTarget ?: ""
    curPod    = null
    curTarget = null
    step      = null
    if (ok) { built++; if (target == targets.last) podsDone++ }
    else { failed++; failedPod = pod }

    lines := Str[,]
    if (!quiet)
    {
      lines.add("  " + nameCol(pod) + targetCol(target) +
        (ok ? color(Term.green, "ok") : color(Term.red, "fail")) + " " +
        color(Term.dim, "(${StatusBar.fmtDurMs(now - podStart)})"))

      // warnings on a good pod are shown inline without the build
      // steps after them; errors wait for the summary so they sit
      // right above the final line
      if (ok) msgs.each |s| { if (!s.startsWith(" ")) lines.add(color(Term.dim, "    $s")) }
    }
    if (!ok) details.add([color(Term.red, "FAIL: $pod [$target]")].addAll(msgs))
    msgs.clear
    printAbove(lines)
  }

  private static const Regex headerRegex := Regex<|^(\w+) \[([^\]\s]+)\]$|>

//////////////////////////////////////////////////////////////////////////
// Rendering
//////////////////////////////////////////////////////////////////////////

  ** Line for the pod currently building with its latest build step
  ** in dim to the right, or null if none.
  internal Str? liveLine()
  {
    if (quiet) return null
    pod := curPod
    if (pod == null && step == null) return null

    s := step ?: ""
    timer := " (${StatusBar.fmtDur(now - podStart)})"

    // keep on one line so cursor math in 'erase' holds
    col   := pod == null ? "" : nameCol(pod, false) + targetCol(curTarget ?: "", false)
    avail := width - 1 - ("  " + col + timer).size
    if (avail < 4) s = ""
    else if (s.size > avail) s = s[0..<avail-1] + "…"

    head := pod == null ? "" : nameCol(pod) + targetCol(curTarget ?: "")
    return "  " + head + color(Term.dim, s.isEmpty ? timer.trimStart : s + timer)
  }

  ** Target in brackets padded so status words line up.
  private Str targetCol(Str target, Bool colored := true)
  {
    s := "[$target]".padr(targetWidth + 2) + " "
    return colored ? color(Term.magenta, s) : s
  }

  ** Pod name plus dim dot leaders out to the status column; the
  ** longest name still gets 'Runner.minDots'.
  private Str nameCol(Str pod, Bool colored := true)
  {
    dots := "·" * (nameWidth - pod.size + Runner.minDots)
    return "$pod " + (colored ? color(Term.dim, dots) : dots) + " "
  }

  ** Print lines above the status bar.
  private Void printAbove(Str[] lines)
  {
    lock.lock
    try
    {
      if (tty) out.print(erase)
      lines.each |s| { out.printLine(s) }
      redraw
    }
    finally lock.unlock
  }

  ** Redraw live pod line and status bar in place; called from
  ** both the output pump thread and the ticker.
  private Void redraw()
  {
    if (!tty) return
    lock.lock
    try
    {
      if (!running.val) return
      live := liveLine
      buf  := StrBuf().add(erase)
      drawn := 0
      if (live != null) { buf.add(live).add("\n"); drawn++ }
      if (!quiet) { buf.add("\n"); drawn++ }
      label := quiet ? curPod : null
      buf.add(StatusBar.render(total, built, failed, label, elapsed, width, true, "BUILD"))
      liveDrawn = drawn
      out.print(buf.toStr).flush
    }
    finally lock.unlock
  }

  ** Escape sequence to clear the status bar and any live
  ** lines above it, leaving the cursor where they started.
  private Str erase()
  {
    s := Term.clearLine + Term.upClearLine * liveDrawn
    liveDrawn = 0
    return s
  }

  ** Print errors and final summary and return exit code.
  internal Int summary(Int exit)
  {
    dur := StatusBar.fmtDur(elapsed)
    out.printLine

    details.each |lines|
    {
      lines.each |s| { out.printLine(s) }
      out.printLine
    }

    // output dirs confirm where pods landed; warnings get a count
    // since the lines themselves are dim and easy to scroll past
    to := outDirs.isEmpty ? "" : " to " + outDirs.map |d| { relPath(d) }.join(", ")
    ws := warns == 0 ? "" : " " + color(Term.yellow, "[" + (warns == 1 ? "1 warning" : "$warns warnings") + "]")

    // name what ran; counts are pods through the last target
    verb := "ran ${targets.last} on"
    if (targets == ["clean"]) verb = "cleaned"
    else if (targets.last == "compile") verb = targets.contains("clean") ? "cleaned and built" : "built"
    if (failedPod == null && exit == 0)
    {
      out.printLine(color(Term.green, "✓ ${verb.capitalize} ${pods(podsDone)}$to") + ws + color(Term.green, " in $dur"))
      return 0
    }

    what := failedPod == null || failedPod.isEmpty ? "Build failed (exit $exit)" : "$failedPod failed"
    out.printLine(color(Term.red, "✗ $what; $verb $podsDone of ${pods(podCount)}$to") + ws + color(Term.red, " in $dur"))
    return 1
  }

  ** Path relative to cwd when under it, else the full OS path.
  private Str relPath(File f)
  {
    rel := f.uri.relTo(cwd.uri).toStr
    if (!rel.startsWith("..") && !rel.startsWith("/")) return rel
    return f.isDir ? f.osPath + File.sep : f.osPath
  }

  private static Str pods(Int n) { n == 1 ? "1 pod" : "$n pods" }

  private Str color(Str c, Str s) { tty ? "$c$s$Term.reset" : s }

  private Duration elapsed() { now - start }

  ** Current time; tests may freeze it with 'fixedNow'.
  private Duration now() { fixedNow ?: Duration.now }

  ** Fixed clock for tests.
  internal Duration? fixedNow

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private OutStream out
  private const File[] scripts
  private const Str[] targets
  private const Bool quiet
  private const Int total
  private const Int podCount
  private Int targetWidth
  private Int podsDone
  private Str? curTarget
  private const Bool tty
  private const Int width
  private const Duration start := Duration.now
  private const File cwd
  private File[] outDirs := [,]
  private Int warns
  private Int nameWidth
  private Int built
  private Int failed
  private Str? failedPod
  private Str? curPod
  private Str? step
  private Duration podStart := Duration.now
  private Str[] msgs := [,]
  private Str[][] details := [,]
  private Int liveDrawn
  private const Lock lock := Lock.makeReentrant
  private const AtomicBool running := AtomicBool(true)
  private const AtomicBool done := AtomicBool(false)
}
