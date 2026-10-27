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

** Builder spawns 'fan <build.fan>', parses its output, and renders
** one line per pod with the same live status bar as Runner.  The
** running pod stays pinned above the bar with its current build
** step to the right in dim text.
**
** Build output is line based: a top level '<target> [<pod>]' line
** starts a pod, indented lines are progress steps, and any other
** top level line is an error or warning for the current pod, until
** 'BUILD SUCCESS' or 'BUILD FAILED'.
**
** Prototype; hidden as 'jig _build [<pod> | <file.fan>]'.
class Builder
{
  ** Entry point for 'jig _build'; with no args build the root
  ** script, else the pod named 'args[0]' under the root script,
  ** or the build script at path 'args[0]'.
  static Int main(Str[] args, Bool quiet)
  {
    if (args.size > 1) { echo("ERR: usage: jig _build [<pod> | <file.fan>]"); return 1 }

    BuildScript? script
    try
    {
      arg := args.first
      if (arg != null && arg.endsWith(".fan")) script = load(File.os(arg).normalize)
      else
      {
        script = load(findRoot)
        if (arg != null) script = findPod(script, arg) ?: throw ArgErr("Unknown pod: $arg")
      }
    }
    catch (ArgErr e) { echo("ERR: $e.msg"); return 1 }

    // rewriting the pod file jig is running from breaks class loading
    pods := JigBuild.podNames(script)
    self := Builder#.pod.name
    if (pods.contains(self) && Env.cur.findPodFile(self)?.normalize == (Env.cur.workDir + `lib/fan/${self}.pod`).normalize)
    {
      echo("ERR: cannot rebuild running ${self}.pod; use 'fan build.fan' or an installed jig")
      return 1
    }
    return Builder(script.scriptFile, pods, quiet).run
  }

  ** Root build script: './build.fan', else '<workDir>/src/build.fan'.
  static File findRoot()
  {
    cwd := File.os(".").normalize
    f := cwd + `build.fan`
    if (f.exists) return f
    f = Env.cur.workDir + `src/build.fan`
    if (f.exists) return f
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

  ** Find BuildPod for 'name' anywhere under 'script', or null.
  static BuildPod? findPod(BuildScript script, Str name)
  {
    if (script is BuildPod) return ((BuildPod)script).podName == name ? script : null
    if (script is BuildGroup)
      return ((BuildGroup)script).children.eachWhile |c| { findPod(c, name) }
    return null
  }

  ** Create builder for 'script' which is expected to build 'pods'.
  new make(File script, Str[] pods, Bool quiet := false, Bool? tty := null, OutStream out := Env.cur.out, File? cwd := null)
  {
    this.cwd    = cwd ?: File.os(".").normalize
    this.script = script
    this.total  = pods.size
    pods.each |p| { nameWidth = nameWidth.max(p.size) }
    this.quiet  = quiet
    this.tty    = tty ?: Term.isTty
    this.width  = this.tty ? Term.width : 80
    this.out    = out
  }

  ** Run build and return exit code.
  Int run()
  {
    if (!quiet) printAbove([color(Term.bold, title)])
    pool := startTicker
    exit := Term.exec(Term.fan.add(script.osPath), |line| { parseLine(line) }) |->Bool| { done.val }
    if (!done.val && curPod != null) endPod(exit == 0)

    // stop ticker before writing summary
    running.val = false
    pool?.stop?.join(1sec)
    if (tty) out.print(erase).flush
    return summary(exit)
  }

  ** Header line: script path relative to cwd when under it.
  private Str title() { relPath(script) }

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

    // '<target> [<pod>]' starts a pod, or another target of same pod
    m := headerRegex.matcher(line)
    if (m.matches)
    {
      pod := m.group(2)
      if (pod != curPod) { endPod(true); startPod(pod) }
      step = line
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
      dir := File(step[15..-2].toUri).parent
      if (dir != null && !outDirs.contains(dir)) outDirs.add(dir)
    }
    catch (Err e) {}
  }

  private Void startPod(Str pod)
  {
    curPod   = pod
    podStart = now
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

    curPod = null
    step   = null
    if (ok) built++
    else { failed++; failedPod = pod }

    lines := Str[,]
    if (!quiet)
    {
      lines.add("  " + nameCol(pod) +
        (ok ? color(Term.green, "ok") : color(Term.red, "fail")) + " " +
        color(Term.dim, "(${StatusBar.fmtDurMs(now - podStart)})"))

      // warnings on a good pod are shown inline without the build
      // steps after them; errors wait for the summary so they sit
      // right above the final line
      if (ok) msgs.each |s| { if (!s.startsWith(" ")) lines.add(color(Term.dim, "    $s")) }
    }
    if (!ok) details.add([color(Term.red, "FAIL: $pod")].addAll(msgs))
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
    pod := curPod
    if (quiet || pod == null) return null

    s := step ?: ""
    timer := " (${StatusBar.fmtDur(now - podStart)})"

    // keep on one line so cursor math in 'erase' holds
    avail := width - 1 - ("  " + nameCol(pod, false) + timer).size
    if (avail < 4) s = ""
    else if (s.size > avail) s = s[0..<avail-1] + "…"

    return "  " + nameCol(pod) + color(Term.dim, s + timer)
  }

  ** Pod name plus dim dot leaders out to the status column.
  private Str nameCol(Str pod, Bool colored := true)
  {
    n := nameWidth - pod.size
    if (n <= 0) return "$pod  "
    dots := "·" * n
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

    if (failedPod == null && exit == 0)
    {
      out.printLine(color(Term.green, "✓ Built ${pods(built)}$to") + ws + color(Term.green, " in $dur"))
      return 0
    }

    what := failedPod == null || failedPod.isEmpty ? "Build failed (exit $exit)" : "$failedPod failed"
    out.printLine(color(Term.red, "✗ $what; built $built of ${pods(total)}$to") + ws + color(Term.red, " in $dur"))
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
  private const File script
  private const Bool quiet
  private const Int total
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
