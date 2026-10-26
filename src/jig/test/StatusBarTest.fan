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
      "[░░░░░░░░░░░░░░░░░░░░] 0/10  ✓ 0  0.0sec")
    verifyEq(render(10, 5, 0, "acme::FooTest.testA", 1234ms, 80),
      "[██████████░░░░░░░░░░] 5/10  ✓ 5  1.2sec  acme::FooTest.testA")
    verifyEq(render(4, 3, 1, null, 65sec, 80),
      "[████████████████████] 4/4  ✓ 3  ✗ 1  1min 5.0sec")

    // never overfill
    verifyEq(render(1, 2, 0, null, 0ms, 80),
      "[████████████████████] 2/1  ✓ 2  0.0sec")
    verifyEq(render(0, 0, 0, null, 0ms, 80),
      "[░░░░░░░░░░░░░░░░░░░░] 0/0  ✓ 0  0.0sec")
  }

  Void testTruncate()
  {
    // prefix is 40 chars; width 62 leaves 19 for name
    s := render(10, 0, 0, "acme::SomeLongTest.testSomething", 0ms, 62)
    verifyEq(s, "[░░░░░░░░░░░░░░░░░░░░] 0/10  ✓ 0  0.0sec  …Test.testSomething")
    verifyEq(s.size, 61)

    // too narrow for a useful name
    verifyEq(render(10, 0, 0, "acme::FooTest.testA", 0ms, 47),
      "[░░░░░░░░░░░░░░░░░░░░] 0/10  ✓ 0  0.0sec")
  }

  Void testColor()
  {
    s := StatusBar.render(10, 5, 1, "acme::FooTest.testA", 0ms, 80, true)
    verify(s.contains(Term.red))
    verify(s.endsWith("  acme::FooTest.testA"))
    verifyEq(Regex<|\u001b\[\d+m|>.split(s).join, render(10, 5, 1, "acme::FooTest.testA", 0ms, 80))
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
    verifyEq(StatusBar.fmtDurMs(5000ms), "5sec")
    verifyEq(StatusBar.fmtDurMs(5499ms), "5sec")
    verifyEq(StatusBar.fmtDurMs(5912ms), "6sec")
    verifyEq(StatusBar.fmtDurMs(59499ms), "59sec")
    verifyEq(StatusBar.fmtDurMs(59500ms), "1min 0sec")
    verifyEq(StatusBar.fmtDurMs(60sec), "1min 0sec")
    verifyEq(StatusBar.fmtDurMs(62400ms), "1min 2sec")
    verifyEq(StatusBar.fmtDurMs(62500ms), "1min 3sec")
  }

  private Str render(Int total, Int passed, Int failed, Str? cur, Duration d, Int w)
  {
    StatusBar.render(total, passed, failed, cur, d, w, false)
  }
}
