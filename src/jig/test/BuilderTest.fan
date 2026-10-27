//
// Copyright (c) 2026, Novant LLC
// Licensed under the MIT License
//
// History:
//   27 Oct 2026  Andy Frank  Creation
//

*************************************************************************
** BuilderTest
*************************************************************************

class BuilderTest : Test
{
  Void testSuccess()
  {
    buf := Buf()
    b := Builder(`/x/src/build.fan`.toFile, ["acme", "betaWeb"], false, false, buf.out, `/x/`.toFile)
    b.fixedNow = 0ms
    parse(b,
      "compile [acme]
         Compile [acme]
           FindSourceFiles [3 files]
           WritePod [file:/x/lib/fan/acme.pod]
       compile [betaWeb]
         Compile [betaWeb]
       /x/src/betaWeb/fan/Foo.fan(3,1): WARN Unused import")
    b.fixedNow = 1200ms
    parse(b,
      "    WritePod [file:/x/lib/fan/betaWeb.pod]
       BUILD SUCCESS [1200ms]!")
    verifyEq(b.summary(0), 0)
    lines := buf.flip.readAllLines
    verifyEq(lines[0..3],
      ["  acme ··· ok (0ms)",
       "  betaWeb  ok (1200ms)",
       "    /x/src/betaWeb/fan/Foo.fan(3,1): WARN Unused import",
       ""])
    verify(lines[4].startsWith("✓ Built 2 pods to lib/fan/ [1 warning] in "))
  }

  Void testFail()
  {
    buf := Buf()
    b := Builder(`/x/src/build.fan`.toFile, ["acme", "beta", "gamma"], false, false, buf.out)
    b.fixedNow = 0ms
    parse(b,
      "compile [acme]
         Compile [acme]
       compile [beta]
         Compile [beta]
           FindSourceFiles [1 files]
       /x/src/beta/fan/Foo.fan(1,25): Unknown type 'Bar'
         extra detail
       BUILD FAILED [19ms]!
       ignored after done")
    verifyEq(b.summary(255), 1)
    lines := buf.flip.readAllLines
    verifyEq(lines[0..-2],
      ["  acme · ok (0ms)",
       "  beta · fail (0ms)",
       "",
       "FAIL: beta",
       "/x/src/beta/fan/Foo.fan(1,25): Unknown type 'Bar'",
       "  extra detail",
       ""])
    verify(lines[-1].startsWith("✗ beta failed; built 1 of 3 pods in "))
  }

  Void testQuietAndLive()
  {
    buf := Buf()
    b := Builder(`/x/build.fan`.toFile, ["acme"], true, false, buf.out)
    parse(b, "compile [acme]\n  Compile [acme]")
    verifyNull(b.liveLine)

    b = Builder(`/x/build.fan`.toFile, ["acme"], false, false, buf.out)
    b.fixedNow = 0ms
    parse(b, "compile [acme]\n  Compile [acme]\n    FindSourceFiles [3 files]")
    verifyEq(b.liveLine, "  acme  FindSourceFiles [3 files] (0.0sec)")
  }

  Void testFindPod()
  {
    verifyEq(Builder.findPod(FxPod(), "fxPod")?.podName, "fxPod")
    verifyNull(Builder.findPod(FxPod(), "nope"))
  }

  private Void parse(Builder b, Str s) { s.splitLines.each |line| { b.parseLine(line) } }
}
