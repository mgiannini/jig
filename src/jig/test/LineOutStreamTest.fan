//
// Copyright (c) 2026, Novant LLC
// Licensed under the MIT License
//
// History:
//   26 Oct 2026  Andy Frank  Creation
//

*************************************************************************
** LineOutStreamTest
*************************************************************************

class LineOutStreamTest : Test
{
  Void testLines()
  {
    lines := Str[,]
    out := LineOutStream(|Str s| { lines.add(s) })
    out.print("alpha\nbe")
    verifyEq(lines, ["alpha"])
    out.print("ta\r\n\ngam✓\n")
    verifyEq(lines, ["alpha", "beta", "", "gam✓"])

    // trailing partial line delivered on close
    out.print("tail")
    out.close
    verifyEq(lines, ["alpha", "beta", "", "gam✓", "tail"])
  }

  Void testWriteBuf()
  {
    lines := Str[,]
    out := LineOutStream(|Str s| { lines.add(s) })
    buf := Buf().print("xxone\ntwo\nyy")
    buf.seek(2)
    out.writeBuf(buf, 8)
    verifyEq(lines, ["one", "two"])
  }

  Void testExec()
  {
    lines := Str[,]
    exit := Term.exec(["sh", "-c", "echo one; echo two >&2; exit 3"]) |s| { lines.add(s) }
    verifyEq(exit, 3)
    verifyEq(lines.sort, ["one", "two"])
  }
}
