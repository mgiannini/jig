//
// Copyright (c) 2026, Novant LLC
// Licensed under the MIT License
//
// History:
//   4 Nov 2026  Andy Frank  Creation
//

*************************************************************************
** LiveRegionTest
*************************************************************************

class LiveRegionTest : Test
{
  Void testLive()
  {
    buf := Buf()
    lines := ["live", "", "bar"]
    r := LiveRegion(Term(buf.out, Buf().out, true, true)) |->Str[]| { lines }

    // first draw has nothing to erase but the current line
    r.redraw
    verifyEq(read(buf), "\\S\\r\\K" + "live\n\nbar" + "\\E")

    // printAbove erases the 3 line region, prints, then redraws
    lines = ["bar2"]
    r.printAbove(["one", "two"])
    verifyEq(read(buf), "\\S\\r\\K\\U\\K\\U\\K" + "one\ntwo\n" + "bar2" + "\\E")

    // stop erases region without sync wrapper; later output is plain
    r.stop
    verifyEq(read(buf), "\\r\\K")
    r.redraw
    verifyEq(read(buf), "")
    r.printAbove(["after"])
    verifyEq(read(buf), "\\S\\r\\K" + "after\n" + "\\E")
  }

  Void testNotLive()
  {
    buf := Buf()
    r := LiveRegion(Term(buf.out, Buf().out, false, false)) |->Str[]| { throw Err("not drawn") }
    r.start
    r.redraw
    r.printAbove(["one", "two"])
    r.stop
    verifyEq(buf.flip.readAllStr, "one\ntwo\n")
  }

  ** Read and clear 'buf' with escapes shown as short codes.
  private Str read(Buf buf)
  {
    s := buf.flip.readAllStr(false)
    buf.clear
    return s.replace("\u001b[?2026h", "\\S")
            .replace("\u001b[?2026l", "\\E")
            .replace("\u001b[1A", "\\U")
            .replace("\u001b[2K", "\\K")
            .replace("\r", "\\r")
  }
}
