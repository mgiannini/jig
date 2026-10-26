//
// Copyright (c) 2026, Novant LLC
// Licensed under the MIT License
//
// History:
//   26 Oct 2026  Andy Frank  Creation
//

using concurrent

*************************************************************************
** Runner
*************************************************************************

** Runner spawns fant, parses its output, and renders a live
** status bar with failures printed above it.
class Runner : FantListener
{
  ** Create runner; in 'quiet' mode only failures are printed,
  ** otherwise a pass/fail line is printed for each test type
  ** grouped by pod.
  new make(Str[] targets, Str[] tests, Bool quiet := false, Bool? tty := null, OutStream out := Env.cur.out)
  {
    this.targets = targets
    this.total   = tests.size

    // expected methods per type and type name column per pod
    tests.each |q|
    {
      type := typeOf(q)
      typeTotals[type] = (typeTotals[type] ?: 0) + 1
      pod  := podOf(q)
      name := type[pod.size+2..-1]
      podWidths[pod] = (podWidths[pod] ?: 0).max(name.size)
    }

    // count digits fit the largest type total in each pod
    typeTotals.each |n, type|
    {
      pod := podOf(type)
      countWidths[pod] = (countWidths[pod] ?: 0).max(n.toStr.size)
    }

    this.quiet   = quiet
    this.tty     = tty ?: Term.isTty
    this.width   = this.tty ? Term.width : 80
    this.out     = out
  }

  ** Run fant for '-es' or '-js' with output passed through as-is.
  static Int passthrough(Str flag, Str[] targets)
  {
    out := Env.cur.out
    return Term.exec(Term.fant.add(flag).addAll(targets)) |line| { out.printLine(line).flush }
  }

  ** Run tests and return exit code.
  Int run()
  {
    parser := FantParser(this)
    redraw
    pool := startTicker
    exit := Term.exec(Term.fant.addAll(targets), |line| { parser.parseLine(line) }) |->Bool| { parser.isDone }
    parser.finish
    if (!quiet) printType

    // stop ticker before writing summary
    running.val = false
    pool?.stop?.join(1sec)
    if (tty) out.print(erase).flush
    return summary(exit, parser.isDone)
  }

  ** Redraw every 100ms so elapsed time moves during long tests.
  private ActorPool? startTicker()
  {
    if (!tty) return null
    pool := ActorPool { it.name = "jigTicker"; it.maxThreads = 1 }
    self := Unsafe(this)
    flag := this.running
    Actor(pool) |->Obj?|
    {
      while (flag.val) { Actor.sleep(100ms); ((Runner)self.val).redraw }
      return null
    }.send(null)
    return pool
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
    if (quiet) redraw
    else checkType
  }

  override Void onFail(Str qname, Str[] output, Str[] trace)
  {
    failed++
    failures.add(qname)
    if (quiet)
    {
      printAbove(failLines(qname, output, trace, "").add(""))
    }
    else
    {
      typeFailed++
      typeFails.addAll(failLines(qname[qname.index(".")+1..-1], output, trace, "    "))
      checkType
    }
  }

  override Void onStray(Str line) { printAbove([line]) }

  override Void onSummary(Int types, Int methods, Int verifies) { this.verifies = verifies }

//////////////////////////////////////////////////////////////////////////
// Rendering
//////////////////////////////////////////////////////////////////////////

  ** Lines for a failed test with a red header to stand out.
  private Str[] failLines(Str name, Str[] output, Str[] trace, Str indent)
  {
    lines := [indent + color(Term.red, "FAIL: $name")]
    output.each |s| { lines.add(color(Term.dim, "$indent  | $s")) }
    trimTrace(trace).each |s| { lines.add("$indent  $s") }
    return lines
  }

  ** Print current type line once all its expected methods ran.
  private Void checkType()
  {
    if (typePassed + typeFailed >= (typeTotals[curType] ?: 0)) printType
    else redraw
  }

  ** Print pod header if this is the first type of a new pod.
  private Void printPod(Str pod)
  {
    if (pod == curPod) return
    lines := Str[,]
    if (curPod != null) lines.add("")
    lines.add(tty ? "$Term.bold$pod$Term.reset" : pod)
    curPod = pod
    printAbove(lines)
  }

  ** Print final line for current type followed by its failures.
  private Void printType()
  {
    type := curType
    if (type == null) return
    curType = null

    expected := typeTotals[type] ?: typePassed + typeFailed
    ok := typeFailed == 0 && typePassed >= expected
    lines := ["  ${typeName(type)}  " +
      color(Term.magenta, countStr(type, typePassed, expected)) + " " +
      (ok ? color(Term.green, "pass") : color(Term.red, "fail")) +
      " (${StatusBar.fmtDurMs(now - typeStart)})"]
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
    avail := width - 1 - "  ${typeName(type)}  $count$fails  $timer".size
    if (avail < 4) method = ""
    else if (method.size > avail) method = method[0..<avail-1] + "…"

    s := "  ${typeName(type)}  " + color(Term.magenta, count)
    if (typeFailed > 0) s += " " + color(Term.red, "$typeFailed failed")
    if (!method.isEmpty) s += "  " + color(Term.dim, method + timer)
    return s
  }

  ** Format '[ 4/ 4]' with both sides right aligned to the pod's
  ** count digits so slashes and totals line up.
  private Str countStr(Str type, Int passed, Int expected)
  {
    w := countWidths[podOf(type)] ?: 0
    return "[" + passed.toStr.padl(w) + "/" + expected.toStr.padl(w) + "]"
  }

  ** Type name without pod, padded to align within its pod.
  private Str typeName(Str type)
  {
    pod := podOf(type)
    return type[pod.size+2..-1].padr(podWidths[pod] ?: 0)
  }

  private static Str typeOf(Str qname) { qname[0..<qname.indexr(".")] }

  private static Str podOf(Str qname) { qname[0..<qname.index("::")] }

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

  ** Redraw live type line and status bar in place; called from
  ** both the output pump thread and the ticker, so serialized
  ** with 'lock'.
  private Void redraw()
  {
    if (!tty) return
    lock.lock
    try
    {
      if (!running.val) return
      live := liveLine
      buf  := StrBuf().add(erase)
      if (live != null) buf.add(live).add("\n")
      // live line already shows the method in default mode
      buf.add(StatusBar.render(total, passed, failed, quiet ? current : null, elapsed, width))
      liveDrawn = live == null ? 0 : 1
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
    dur := StatusBar.fmtDur(elapsed)
    vs  := verifies == null ? "" : " [$verifies.toLocale verifies]"

    if (curPod != null) out.printLine

    Int code := 1
    if (!complete)
      out.printLine(color(Term.red, "✗ fant exited early (exit $exit): ran $ran of ${tests(total)} in $dur"))
    else if (failed > 0)
      out.printLine(color(Term.red, "✗ $failed failed, $passed passed of ${tests(total)}$vs in $dur"))
    else
    {
      msg := passed == 1 ? "1 test passed" : "All $passed tests passed"
      out.printLine(color(Term.green, "✓ $msg$vs in $dur"))
      code = 0
    }

    // one line per failure with how many of its type failed
    w := failures.reduce(0) |Int r, q| { r.max(q.size) }
    failures.each |q|
    {
      type := typeOf(q)
      n := failures.findAll { typeOf(it) == type }.size
      out.printLine(color(Term.red, "✗ ${q.padr(w)} [$n/${typeTotals[type] ?: n} failed]"))
    }
    return code
  }

  private static Str tests(Int n) { n == 1 ? "1 test" : "$n tests" }

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
  private const Str[] targets
  private const Bool quiet
  private const Int total
  private const Bool tty
  private const Int width
  private const Duration start := Duration.now
  private Int passed
  private Int failed
  private Int? verifies
  private Str? current
  private Duration typeStart := Duration.now
  private Duration methodStart := Duration.now
  private Str[] failures := [,]
  private Str:Int typeTotals := [:]
  private Str:Int podWidths := [:]
  private Str:Int countWidths := [:]
  private Str? curPod
  private Str? curType
  private Int typePassed
  private Int typeFailed
  private Str[] typeFails := [,]
  private Int liveDrawn
  private const Lock lock := Lock.makeReentrant
  private const AtomicBool running := AtomicBool(true)
}
