//
// Copyright (c) 2026, Novant LLC
// Licensed under the MIT License
//
// History:
//   26 Oct 2026  Andy Frank  Creation
//

using build

*************************************************************************
** JigBuildTest
*************************************************************************

class JigBuildTest : Test
{
  Void testPodNames()
  {
    // groups compile child scripts from disk, so are covered by
    // running a real BuildGroup rather than here
    verifyEq(JigBuild.podNames(FxPod()), ["fxPod"])
  }
}

internal class FxPod : BuildPod { new make() { podName = "fxPod" } }
