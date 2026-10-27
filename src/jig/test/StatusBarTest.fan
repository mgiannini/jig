//
// Copyright (c) 2026, Novant LLC
// Licensed under the MIT License
//
// History:
//   26 Oct 2026  Andy Frank  Creation
//

*************************************************************************
** StatusBarTest
*************************************************************************

class StatusBarTest : Test
{
  Void testRender()
  {
    verifyEq(render(10, 0, 0, null, 0ms, 80),
      "[${b(0)}] 0% 0/10 | ✓ 0 0.0sec")
    verifyEq(render(10, 5, 0, "acme [5/10]", 1234ms, 100),
      "[${b(10)}] 50% 5/10 | ✓ 5 1.2sec | acme [5/10]")
    verifyEq(render(4, 3, 1, null, 65sec, 80),
      "[${b(20)}] 100% 4/4 | ✓ 3 ✗ 1 1min 5.0sec")

    // never overfill
    verifyEq(render(1, 2, 0, null, 0ms, 80),
      "[${b(20)}] 100% 2/1 | ✓ 2 0.0sec")
    verifyEq(render(0, 0, 0, null, 0ms, 80),
      "[${b(0)}] 0% 0/0 | ✓ 0 0.0sec")
  }

  Void testMode()
  {
    verifyEq(StatusBar.render(10, 5, 0, "acme", 1234ms, 100, false, "BUILD"),
      "BUILD [${b(10)}] 50% 5/10 | ✓ 5 1.2sec | acme")

    // mode counts toward width so label is dropped first
    verifyEq(StatusBar.render(10, 5, 0, "acme", 1234ms, 55, false, "BUILD"),
      "BUILD [${b(10)}] 50% 5/10 | ✓ 5 1.2sec")
  }

  Void testBar()
  {
    // eighth-cell partial blocks; percent rounds down
    verifyEq(StatusBar.bar(2, 3), b(13, "▎"))
    verifyEq(StatusBar.bar(1, 160), b(0, "▏"))
    verifyEq(StatusBar.bar(7, 160), b(0, "▉"))
    verifyEq(StatusBar.bar(8, 160), b(1))
    verifyEq(StatusBar.bar(5, 0), b(0))
    verifyEq(render(3, 2, 0, null, 0ms, 80),
      "[" + b(13, "▎") + "] 66% 2/3 | ✓ 2 0.0sec")
  }

  Void testFit()
  {
    // full line is 64 chars; drops label, then time to fit
    verifyEq(render(1324, 80, 0, "core [79/149]", 4800ms, 70),
      "[" + b(1, "▏") + "] 6% 80/1324 | ✓ 80 4.8sec | core [79/149]")
    verifyEq(render(1324, 80, 0, "core [79/149]", 4800ms, 60),
      "[" + b(1, "▏") + "] 6% 80/1324 | ✓ 80 4.8sec")
    verifyEq(render(1324, 80, 0, "core [79/149]", 4800ms, 45),
      "[" + b(1, "▏") + "] 6% 80/1324 | ✓ 80")
  }

  Void testTruncate()
  {
    // base line is 43 chars plus ' | '; width 67 leaves 20 for label
    s := render(10, 0, 0, "acme::SomeLongTest.testSomething", 0ms, 67)
    verifyEq(s, "[${b(0)}] 0% 0/10 | ✓ 0 0.0sec | …gTest.testSomething")
    verifyEq(s.size, 66)

    // under 12 columns left drops the label
    verifyEq(render(10, 0, 0, "acme::FooTest.testA", 0ms, 58),
      "[${b(0)}] 0% 0/10 | ✓ 0 0.0sec")
  }

  Void testColor()
  {
    s := StatusBar.render(10, 5, 1, "acme::FooTest.testA", 0ms, 100, true)
    verify(s.contains(Term.red))
    verify(s.endsWith("acme::FooTest.testA"))
    verifyEq(Regex<|\u001b\[\d+m|>.split(s).join, render(10, 5, 1, "acme::FooTest.testA", 0ms, 100))
  }

  ** Bar with 'full' cells, optional partial cell, rest empty.
  private Str b(Int full, Str partial := "")
  {
    "█" * full + partial + "░" * (StatusBar.barSize - full - partial.size)
  }

  Void testFmtDur()
  {
    verifyEq(StatusBar.fmtDur(0ms), "0.0sec")
    verifyEq(StatusBar.fmtDur(99ms), "0.0sec")
    verifyEq(StatusBar.fmtDur(1250ms), "1.2sec")
    verifyEq(StatusBar.fmtDur(59999ms), "59.9sec")
    verifyEq(StatusBar.fmtDur(60sec), "1min 0sec")
    verifyEq(StatusBar.fmtDur(2min + 5sec + 400ms), "2min 5sec")
    verifyEq(StatusBar.fmtDur(2min + 5sec + 500ms), "2min 6sec")
    verifyEq(StatusBar.fmtDur(2min + 59sec + 600ms), "3min 0sec")
    verifyEq(StatusBar.fmtDur(75min), "75min 0sec")
  }

  Void testFmtBarDur()
  {
    verifyEq(StatusBar.fmtBarDur(0ms), "0.0sec")
    verifyEq(StatusBar.fmtBarDur(12345ms), "12.3sec")
    verifyEq(StatusBar.fmtBarDur(59999ms), "59.9sec")
    verifyEq(StatusBar.fmtBarDur(60sec), "1min 0.0sec")
    verifyEq(StatusBar.fmtBarDur(190400ms), "3min 10.4sec")
    verifyEq(StatusBar.fmtBarDur(75min + 999ms), "75min 0.9sec")
  }

  Void testFmtDurMs()
  {
    verifyEq(StatusBar.fmtDurMs(0ms), "0ms")
    verifyEq(StatusBar.fmtDurMs(1500ms), "1500ms")
    verifyEq(StatusBar.fmtDurMs(4900ms), "4900ms")
    verifyEq(StatusBar.fmtDurMs(4999ms), "4999ms")
    verifyEq(StatusBar.fmtDurMs(5000ms), "5.0sec")
    verifyEq(StatusBar.fmtDurMs(5449ms), "5.4sec")
    verifyEq(StatusBar.fmtDurMs(5450ms), "5.5sec")
    verifyEq(StatusBar.fmtDurMs(7212ms), "7.2sec")
    verifyEq(StatusBar.fmtDurMs(59949ms), "59.9sec")
    verifyEq(StatusBar.fmtDurMs(59950ms), "1min 0sec")
    verifyEq(StatusBar.fmtDurMs(60sec), "1min 0sec")
    verifyEq(StatusBar.fmtDurMs(62400ms), "1min 2sec")
    verifyEq(StatusBar.fmtDurMs(62500ms), "1min 3sec")
  }

  private Str render(Int total, Int passed, Int failed, Str? cur, Duration d, Int w)
  {
    StatusBar.render(total, passed, failed, cur, d, w, false)
  }
}
