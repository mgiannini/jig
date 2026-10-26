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
      "[░░░░░░░░░░░░░░░░░░░░] 0/10  ✓ 0  0.0s")
    verifyEq(render(10, 5, 0, "acme::FooTest.testA", 1234ms, 80),
      "[██████████░░░░░░░░░░] 5/10  ✓ 5  1.2s  acme::FooTest.testA")
    verifyEq(render(4, 3, 1, null, 65sec, 80),
      "[████████████████████] 4/4  ✓ 3  ✗ 1  65.0s")

    // never overfill
    verifyEq(render(1, 2, 0, null, 0ms, 80),
      "[████████████████████] 2/1  ✓ 2  0.0s")
    verifyEq(render(0, 0, 0, null, 0ms, 80),
      "[░░░░░░░░░░░░░░░░░░░░] 0/0  ✓ 0  0.0s")
  }

  Void testTruncate()
  {
    // prefix is 38 chars; width 60 leaves 19 for name
    s := render(10, 0, 0, "acme::SomeLongTest.testSomething", 0ms, 60)
    verifyEq(s, "[░░░░░░░░░░░░░░░░░░░░] 0/10  ✓ 0  0.0s  …Test.testSomething")
    verifyEq(s.size, 59)

    // too narrow for a useful name
    verifyEq(render(10, 0, 0, "acme::FooTest.testA", 0ms, 45),
      "[░░░░░░░░░░░░░░░░░░░░] 0/10  ✓ 0  0.0s")
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
    verifyEq(StatusBar.fmtDur(0ms), "0.0s")
    verifyEq(StatusBar.fmtDur(99ms), "0.0s")
    verifyEq(StatusBar.fmtDur(1250ms), "1.2s")
    verifyEq(StatusBar.fmtDur(2min), "120.0s")
  }

  private Str render(Int total, Int passed, Int failed, Str? cur, Duration d, Int w)
  {
    StatusBar.render(total, passed, failed, cur, d, w, false)
  }
}
