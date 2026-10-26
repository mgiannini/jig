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
  new make(Str[] targets, Str[] tests)
  {
    this.targets = targets
    this.total   = tests.size
    this.tty     = Term.isTty
    this.width   = tty ? Term.width : 80
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

    // stop ticker before writing summary
    running.val = false
    pool?.stop?.join(1sec)
    if (tty) out.print(Term.clearLine).flush
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
    current = qname
    redraw
  }

  override Void onPass(Str qname, Int verifies)
  {
    passed++
    redraw
  }

  override Void onFail(Str qname, Str[] output, Str[] trace)
  {
    failed++
    failures.add(qname)
    lines := Str[,]
    lines.add(color(Term.red, "✗ $qname"))
    output.each |s| { lines.add(color(Term.dim, "  | $s")) }
    trimTrace(trace).each |s| { lines.add("  $s") }
    lines.add("")
    printAbove(lines)
  }

  override Void onStray(Str line) { printAbove([line]) }

  override Void onSummary(Int types, Int methods, Int verifies) { this.verifies = verifies }

//////////////////////////////////////////////////////////////////////////
// Rendering
//////////////////////////////////////////////////////////////////////////

  ** Print lines above the status bar.
  private Void printAbove(Str[] lines)
  {
    lock.lock
    try
    {
      if (tty) out.print(Term.clearLine)
      lines.each |s| { out.printLine(s) }
      redraw
    }
    finally lock.unlock
  }

  ** Redraw status bar in place; called from both the output
  ** pump thread and the ticker, so serialized with 'lock'.
  private Void redraw()
  {
    if (!tty) return
    lock.lock
    try
    {
      if (!running.val) return
      bar := StatusBar.render(total, passed, failed, current, elapsed, width)
      out.print(Term.clearLine).print(bar).flush
    }
    finally lock.unlock
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
  private Int summary(Int exit, Bool complete)
  {
    ran := passed + failed
    dur := StatusBar.fmtDur(elapsed)
    vs  := verifies == null ? "" : " [$verifies.toLocale verifies]"

    if (!failures.isEmpty)
    {
      out.printLine("Failed:")
      failures.each |q| { out.printLine("  $q") }
      out.printLine
    }

    if (!complete)
    {
      out.printLine(color(Term.red, "✗ fant exited early (exit $exit): ran $ran of ${tests(total)} in $dur"))
      return 1
    }

    if (failed > 0)
    {
      out.printLine(color(Term.red, "✗ $failed failed, $passed passed of ${tests(total)}$vs in $dur"))
      return 1
    }

    msg := passed == 1 ? "1 test passed" : "All $passed tests passed"
    out.printLine(color(Term.green, "✓ $msg$vs in $dur"))
    return 0
  }

  private static Str tests(Int n) { n == 1 ? "1 test" : "$n tests" }

  private Str color(Str c, Str s) { tty ? "$c$s$Term.reset" : s }

  private Duration elapsed() { Duration.now - start }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private OutStream out := Env.cur.out
  private const Str[] targets
  private const Int total
  private const Bool tty
  private const Int width
  private const Duration start := Duration.now
  private Int passed
  private Int failed
  private Int? verifies
  private Str? current
  private Str[] failures := [,]
  private const Lock lock := Lock.makeReentrant
  private const AtomicBool running := AtomicBool(true)
}
