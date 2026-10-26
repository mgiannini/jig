//
// Copyright (c) 2026, Novant LLC
// Licensed under the MIT License
//
// History:
//   26 Oct 2026  Andy Frank  Creation
//

*************************************************************************
** MainTest
*************************************************************************

class MainTest : Test
{
  Void testStub()
  {
    verifyEq(Main#.pod.name, "jig")
  }

  Void testWorkPods()
  {
    // missing lib/fan/
    verifyEq(Main.workPods(tempDir), Str[,])

    // only top-level .pod files, sorted
    lib := tempDir + `lib/fan/`
    (lib + `beta.pod`).create
    (lib + `alpha.pod`).create
    (lib + `notes.txt`).create
    (lib + `sub/gamma.pod`).create
    verifyEq(Main.workPods(tempDir), ["alpha", "beta"])
  }
}