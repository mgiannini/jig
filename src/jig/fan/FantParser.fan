//
// Copyright (c) 2026, Novant LLC
// Licensed under the MIT License
//
// History:
//   26 Oct 2026  Andy Frank  Creation
//

using concurrent

*************************************************************************
** FantListener
*************************************************************************

** Callbacks for events parsed from fant output.
mixin FantListener
{
  ** Test method started.
  abstract Void onStart(Str qname)

  ** Test method passed with given number of verifies.
  abstract Void onPass(Str qname, Int verifies)

  ** Test method failed; 'output' is anything the test printed
  ** before failing, and 'trace' is the error stack trace.
  abstract Void onFail(Str qname, Str[] output, Str[] trace)

  ** Output not belonging to any test (ex: fant startup errors).
  abstract Void onStray(Str line)

  ** Final fant summary.
  abstract Void onSummary(Int types, Int methods, Int verifies)
}

*************************************************************************
** FantParser
*************************************************************************

** FantParser is a line based state machine for 'util::TestRunner' output.
class FantParser
{
  new make(FantListener listener) { this.listener = listener }

  ** Has the final summary line been parsed.  Safe to read
  ** from any thread.
  Bool isDone() { done.val }

  ** Parse next line of output, without trailing newline.
  Void parseLine(Str line)
  {
    if (state == stDone) return

    if (state != stSummary && line.startsWith("-- Run: "))
    {
      endTrace
      cur = line[8..-1]
      output.clear
      state = stTest
      listener.onStart(cur)
      return
    }

    switch (state)
    {
      case stIdle:
        if (line.startsWith("Time: ")) state = stSummary
        else if (!line.trim.isEmpty) listener.onStray(line)

      case stTest:
        pass := "   Pass: ${cur} ["
        if (line.startsWith(pass) && line.endsWith("]"))
        {
          verifies := line[pass.size..-2].toInt(10, false) ?: 0
          state = stIdle
          listener.onPass(cur, verifies)
        }
        else if (line == "TEST FAILED")
        {
          trace.clear
          state = stTrace
        }
        else output.add(line)

      case stTrace:
        if (line.startsWith("Time: ")) { endTrace; state = stSummary }
        else trace.add(line)

      case stSummary:
        m := summaryRegex.matcher(line)
        if (m.matches)
        {
          state = stDone
          done.val = true
          listener.onSummary(m.group(1).toInt, m.group(2).toInt, m.group(3).toInt)
        }
    }
  }

  ** Flush any pending failure when output ends without a summary.
  Void finish() { endTrace }

  private Void endTrace()
  {
    if (state != stTrace) return
    state = stIdle
    listener.onFail(cur, trim(output), trim(trace))
  }

  ** Strip trailing blank lines fant prints around failures.
  private static Str[] trim(Str[] lines)
  {
    acc := lines.dup
    while (!acc.isEmpty && acc.last.trim.isEmpty) acc.removeAt(-1)
    return acc
  }

  private static const Regex summaryRegex :=
    Regex<|^\*\*\* .* \[(\d+) types, (\d+) methods, (\d+) verifies\]$|>

  private static const Int stIdle    := 0
  private static const Int stTest    := 1
  private static const Int stTrace   := 2
  private static const Int stSummary := 3
  private static const Int stDone    := 4

  private FantListener listener
  private Int state := stIdle
  private Str cur := ""
  private Str[] output := [,]
  private Str[] trace := [,]
  private const AtomicBool done := AtomicBool(false)
}
