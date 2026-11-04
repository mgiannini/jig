//
// Copyright (c) 2026, Novant LLC
// Licensed under the MIT License
//
// History:
//   26 Oct 2026  Andy Frank  Creation
//

*************************************************************************
** Runner
*************************************************************************

** Runner spawns fant, parses its output, and renders a live
** status bar with results printed above it.  Failures get one line
** as they happen, with full output and trace held for the summary.
class Runner : FantListener
{
  ** Create runner; in 'quiet' mode only failures are printed,
  ** otherwise a pass/fail line is printed for each test type
  ** grouped by pod.
  new make(Str[] targets, Str[] tests, Bool quiet := false, Bool? tty := null, OutStream out := Env.cur.out)
  {
    this.targets = targets
    this.total   = tests.size

    // expected methods per type; name and count columns are sized
    // across all pods so they line up for the whole run
    pods := Str:Str[:]
    tests.each |q|
    {
      type := typeOf(q)
      typeTotals[type] = (typeTotals[type] ?: 0) + 1
      pod := podOf(q)
      pods[pod] = pod
      podTotals[pod] = (podTotals[pod] ?: 0) + 1
      nameWidth = nameWidth.max(type.size - pod.size - 2)
    }
    typeTotals.each |n| { countWidth = countWidth.max(n.toStr.size) }
    this.multiPod = pods.size > 1

    this.quiet   = quiet
    isTty       := tty ?: Term.isTty
    this.term    = Term(out, Env.cur.err, isTty, isTty)
    this.width   = term.width
    this.out     = out
    this.region  = LiveRegion(term) |->Str[]| { frame }
  }

  ** Run fant for '-es' or '-js' with output passed through as-is.
  static Int passthrough(Str flag, Str[] targets)
  {
    out := Env.cur.out
    return Proc.exec(Proc.fant.add(flag).addAll(targets)) |line| { out.printLine(line).flush }
  }

  ** Run tests and return exit code.
  Int run()
  {
    // blank line spaces results off from the command line
    out.printLine
    parser := FantParser(this)
    redraw
    region.start
    exit := Proc.exec(Proc.fant.addAll(targets), |line| { parser.parseLine(line) }) |->Bool| { parser.isDone }
    parser.finish
    if (!quiet) { printType; printAbove(podSummary) }

    // stop ticker before writing summary
    region.stop
    return summary(exit, parser.isDone)
  }

//////////////////////////////////////////////////////////////////////////
// FantListener
//////////////////////////////////////////////////////////////////////////

  override Void onStart(Str qname)
  {

    // fallback if a type ends without reaching its expected count
    type := typeOf(qname)
    if (!quiet && type != curType)
    {
      printType
      printPod(podOf(type))
      typeStart = now
    }
    curType = type
    current = qname
    methodStart = now
    redraw
  }

  override Void onPass(Str qname, Int verifies)
  {
    passed++
    typePassed++
    podPassed++
    if (quiet) redraw
    else checkType
  }

  override Void onFail(Str qname, Str[] output, Str[] trace)
  {
    failed++
    failures.add(qname)

    // one line now; output and trace are saved for the summary so
    // they are all together at the end rather than in the scrollback
    failDetails.add(failLines(qname, output, trace, ""))
    if (quiet)
    {
      printAbove([term.err("FAIL: $qname")])
    }
    else
    {
      typeFailed++
      podFailed++
      typeFails.add("    " + term.err("FAIL: " + qname[qname.index(".")+1..-1]))
      checkType
    }
  }

  override Void onLostFail(Str qname)
  {
    failed++
    failures.add(qname)
    failDetails.add(failLines(qname, Str[,], ["Details lost: fant output was mangled by other threads"], ""))
  }

  override Void onStray(Str line) { printAbove([line]) }

  override Void onSummary(Int types, Int methods, Int verifies) { this.verifies = verifies }

//////////////////////////////////////////////////////////////////////////
// Rendering
//////////////////////////////////////////////////////////////////////////

  ** Lines for a failed test with a red header to stand out.
  private Str[] failLines(Str name, Str[] output, Str[] trace, Str indent)
  {
    lines := [indent + term.err("FAIL: $name")]
    output.each |s| { lines.add(term.dim("$indent  | $s")) }
    trimTrace(trace).each |s| { lines.add("$indent  $s") }
    return lines
  }

  ** Print current type line once all its expected methods ran.
  private Void checkType()
  {
    if (typePassed + typeFailed >= (typeTotals[curType] ?: 0)) printType
    else redraw
  }

  ** Print previous pod's summary and this pod's header if this
  ** is the first type of a new pod.
  private Void printPod(Str pod)
  {
    if (pod == curPod) return
    lines := Str[,]
    if (curPod != null) lines.addAll(podSummary).add("")
    lines.add(term.bold(pod))
    curPod     = pod
    podPassed  = 0
    podFailed  = 0
    podStart   = now
    printAbove(lines)
  }

  ** Summary line for current pod, or empty if this run only covers
  ** one pod since the final summary already says the same thing.
  internal Str[] podSummary()
  {
    if (!multiPod || curPod == null) return Str[,]
    missing := (podTotals[curPod] ?: 0) - podPassed - podFailed
    bad := badCounts(podFailed, missing)
    res := bad.isEmpty
      ? term.ok("✓ $podPassed passed")
      : term.err("✗ $bad$podPassed passed")

    return ["  [$res " + term.dim("(${StatusBar.fmtDurMs(now - podStart)})") + "]"]
  }

  ** Print final line for current type followed by its failures.
  private Void printType()
  {
    type := curType
    if (type == null) return
    curType = null

    expected := typeTotals[type] ?: typePassed + typeFailed
    ok := typeFailed == 0 && typePassed >= expected
    lines := ["  " + typeCol(type) +
      term.accent(countStr(type, typePassed, expected)) + " " +
      (ok ? term.ok("pass") : term.err("fail")) + " " +
      term.dim("(${StatusBar.fmtDurMs(now - typeStart)})")]
    lines.addAll(typeFails)

    typePassed = 0
    typeFailed = 0
    typeFails  = Str[,]
    printAbove(lines)
  }

  ** Line for the type currently running, shown above the status
  ** bar with live counts and the running method, or null if none.
  internal Str? liveLine()
  {
    type := curType
    if (quiet || type == null) return null

    count  := countStr(type, typePassed, typeTotals[type] ?: 0)
    fails  := typeFailed > 0 ? " $typeFailed failed" : ""
    method := current == null ? "" : current[current.indexr(".")+1..-1]
    timer  := " (${StatusBar.fmtDur(now - methodStart)})"

    // keep on one line so cursor math in 'erase' holds
    avail := width - 1 - ("  " + typeCol(type, false) + "$count$fails  $timer").size
    if (avail < 4) method = ""
    else if (method.size > avail) method = method[0..<avail-1] + "…"

    s := "  " + typeCol(type) + term.accent(count)
    if (typeFailed > 0) s += " " + term.err("$typeFailed failed")
    if (!method.isEmpty) s += "  " + term.dim(method + timer)
    return s
  }

  ** Format '[ 4/ 4]' with both sides right aligned to the run's
  ** count digits so slashes and totals line up.
  private Str countStr(Str type, Int passed, Int expected)
  {
    "[" + passed.toStr.padl(countWidth) + "/" + expected.toStr.padl(countWidth) + "]"
  }

  ** Type name without pod plus dim dot leaders out to the count
  ** column, which is aligned across all pods.  The longest name
  ** still gets 'minDots' so every row reads the same.
  private Str typeCol(Str type, Bool colored := true)
  {
    name := type[podOf(type).size+2..-1]
    dots := "·" * (nameWidth - name.size + minDots)
    return "$name " + (colored ? term.dim(dots) : dots) + " "
  }

  ** Fewest dot leaders between a name and its column.
  internal static const Int minDots := 3

  private static Str typeOf(Str qname) { qname[0..<qname.indexr(".")] }

  private static Str podOf(Str qname) { qname[0..<qname.index("::")] }

  ** Print lines above the status bar.
  private Void printAbove(Str[] lines) { region.printAbove(lines) }

  ** Redraw live type line and status bar in place.
  private Void redraw() { region.redraw }

  ** Lines of the live region: live type line and status bar.
  private Str[] frame()
  {
    lines := Str[,]
    live := liveLine
    if (live != null) lines.add(live)

    // blank line separates results from the bar; kept between
    // types too so the bar doesn't jump as each type finishes
    if (!quiet && curPod != null) lines.add("")

    lines.add(StatusBar.render(total, passed, failed, barLabel, elapsed, width, term.color, "TEST"))
    return lines
  }

  ** Label for the status bar: the current pod and its test progress,
  ** which stays pinned once the pod header scrolls away.  The live
  ** line already shows the class and method, but quiet mode has no
  ** live line so shows the current test instead.
  internal Str? barLabel()
  {
    if (quiet) return current
    pod := curPod
    if (pod == null) return null
    return "$pod [${podPassed + podFailed}/${podTotals[pod]}]"
  }

  ** Strip test harness frames (verify internals, reflection,
  ** TestRunner) from a trace, keeping messages and causes.
  static Str[] trimTrace(Str[] lines)
  {
    acc  := Str[,]
    skip := false
    msg  := false
    lines.each |s|
    {
      t := s.trim
      if (!s.startsWith(" ") || msg) { acc.add(s); skip = false; msg = false; return }
      if (t == "Cause:") { acc.add(s); skip = false; msg = true; return }
      if (skip || t.startsWith("fan.sys.Test.")) return
      if (isHarness(t)) { skip = true; return }
      acc.add(s)
    }
    return acc
  }

  private static Bool isHarness(Str frame)
  {
    frame.startsWith("jdk.internal.reflect.") ||
    frame.startsWith("java.lang.reflect.")    ||
    frame.startsWith("fan.sys.Method")        ||
    frame.startsWith("util::TestRunner.")     ||
    frame.endsWith(" More...")
  }

  ** Print final summary and return exit code.
  internal Int summary(Int exit, Bool complete)
  {
    ran := passed + failed
    missing := total - ran
    dur := StatusBar.fmtDur(elapsed)
    vs  := verifies == null ? "" : " [$verifies.toLocale verifies]"

    if (curPod != null || !failDetails.isEmpty) out.printLine

    // full details for each failure, right above the summary line
    failDetails.each |lines|
    {
      lines.each |s| { out.printLine(s) }
      out.printLine
    }

    Int code := 1
    if (!complete)
      out.printLine(term.err("✗ fant exited early (exit $exit): ran $ran of ${tests(total)} in $dur"))
    else if (failed > 0 || missing > 0 || exit != 0)
    {
      // fant exits with its failure count; a mismatch means fant saw
      // something we did not, so show it rather than trust our counts
      note := exit == failed ? "" : " (fant exit $exit)"
      out.printLine(term.err("✗ ${badCounts(failed, missing)}$passed passed of ${tests(total)}$vs in $dur$note"))
    }
    else
    {
      msg := passed == 1 ? "1 test passed" : "All $passed tests passed"
      out.printLine(term.ok("✓ $msg$vs in $dur"))
      code = 0
    }

    // one line per failure with how many of its type failed
    w := failures.reduce(0) |Int r, q| { r.max(q.size) }
    failures.each |q|
    {
      type := typeOf(q)
      n := failures.findAll { typeOf(it) == type }.size
      out.printLine(term.err("✗ ${q.padr(w)} [$n/${typeTotals[type] ?: n} failed]"))
    }
    return code
  }

  ** Leading counts for a summary line with anything not passed.
  ** Tests are 'unrecorded' when fant's lines for them were mangled
  ** by output from other threads, so we have no result for them.
  private static Str badCounts(Int failed, Int missing)
  {
    s := failed > 0 ? "$failed failed, " : ""
    if (missing > 0) s += "$missing unrecorded, "
    return s
  }

  private static Str tests(Int n) { n == 1 ? "1 test" : "$n tests" }

  private Duration elapsed() { now - start }

  ** Current time; tests may freeze it with 'fixedNow'.
  private Duration now() { fixedNow ?: Duration.now }

  ** Fixed clock for tests.
  internal Duration? fixedNow

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private OutStream out
  private Term term
  private LiveRegion region
  private const Str[] targets
  private const Bool quiet
  private const Int total
  private const Int width
  private const Duration start := Duration.now
  private Int passed
  private Int failed
  private Int? verifies
  private Str? current
  private Duration typeStart := Duration.now
  private Duration methodStart := Duration.now
  private Str[] failures := [,]
  private Str[][] failDetails := [,]
  private Str:Int typeTotals := [:]
  private const Bool multiPod
  private Int nameWidth
  private Int countWidth
  private Str? curPod
  private Str:Int podTotals := [:]
  private Int podPassed
  private Int podFailed
  private Duration podStart := Duration.now
  private Str? curType
  private Int typePassed
  private Int typeFailed
  private Str[] typeFails := [,]
}
