//
// Copyright (c) 2026, Novant LLC
// Licensed under the MIT License
//
// History:
//   4 Nov 2026  Andy Frank  Creation
//

*************************************************************************
** TermTest
*************************************************************************

class TermTest : Test
{
  Void testStyle()
  {
    t := Term(Buf().out, Buf().out, true, false)
    verifyEq(t.err("x"),    "\u001b[31mx\u001b[0m")
    verifyEq(t.ok("x"),     "\u001b[32mx\u001b[0m")
    verifyEq(t.warn("x"),   "\u001b[33mx\u001b[0m")
    verifyEq(t.accent("x"), "\u001b[35mx\u001b[0m")
    verifyEq(t.info("x"),   "\u001b[36mx\u001b[0m")
    verifyEq(t.bold("x"),   "\u001b[1mx\u001b[0m")
    verifyEq(t.dim("x"),    "\u001b[2mx\u001b[0m")
    verifyEq(t.dim(null),   "\u001b[2mnull\u001b[0m")
    verifyEq(t.style(Style.bold + Style.err, 3), "\u001b[1;31m3\u001b[0m")
    verifyEq(t.style(Style.none, "x"), "x")

    // nested styles are left as-is
    verifyEq(t.dim("a" + t.err("b") + "c"), "\u001b[2ma\u001b[31mb\u001b[0mc\u001b[0m")

    // color off
    p := Term(Buf().out, Buf().out, false, false)
    verifyEq(p.err("x"), "x")
    verifyEq(p.style(Style.bold + Style.err, 3), "3")
  }

  Void testStyleCombine()
  {
    verifyEq(Style.bold + Style.err, Style("1;31"))
    verifyEq(Style.none + Style.err, Style.err)
    verifyEq(Style.err + Style.none, Style.err)
    verifyEq(Style.none.code, "")
  }

  Void testStrip()
  {
    t := Term(Buf().out, Buf().out, true, false)
    s := t.bold("ab") + " " + t.err("✗ 1")
    verifyEq(Term.strip(s), "ab ✗ 1")
    verifyEq(Term.visibleSize(s), 6)
    verifyEq(Term.strip("plain"), "plain")
    verifyEq(Term.strip("\u001b[?2026hx\u001b[1A\u001b[2Ky"), "xy")
  }

  Void testWidth()
  {
    // width is only detected for live output
    verifyEq(Term(Buf().out, Buf().out, true, false).width, 80)
  }
}
