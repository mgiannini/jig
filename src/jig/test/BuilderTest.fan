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
    b := Builder([`/x/src/build.fan`.toFile], ["acme", "betaWeb"], ["compile"], false, false, buf.out, File(`file:/x/`))
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
      ["  acme ······ [compile] ok (0ms)",
       "  betaWeb ··· [compile] ok (1200ms)",
       "    /x/src/betaWeb/fan/Foo.fan(3,1): WARN Unused import",
       ""])
    verify(lines[4].startsWith("✓ Built 2 pods to lib/fan/ [1 warning] in "))
  }

  Void testFail()
  {
    buf := Buf()
    b := Builder([`/x/src/build.fan`.toFile], ["acme", "beta", "gamma"], ["compile"], false, false, buf.out)
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
      ["  acme ···· [compile] ok (0ms)",
       "  beta ···· [compile] fail (0ms)",
       "",
       "FAIL: beta [compile]",
       "/x/src/beta/fan/Foo.fan(1,25): Unknown type 'Bar'",
       "  extra detail",
       ""])
    verify(lines[-1].startsWith("✗ beta failed; built 1 of 3 pods in "))
  }

  Void testQuietAndLive()
  {
    buf := Buf()
    b := Builder([`/x/build.fan`.toFile], ["acme"], ["compile"], true, false, buf.out)
    parse(b, "compile [acme]\n  Compile [acme]")
    verifyNull(b.liveLine)

    b = Builder([`/x/build.fan`.toFile], ["acme"], ["compile"], false, false, buf.out)
    b.fixedNow = 0ms
    parse(b, "compile [acme]")
    verifyEq(b.liveLine, "  acme ··· [compile] (0.0sec)")
    parse(b, "compile [acme]\n  Compile [acme]\n    FindSourceFiles [3 files]")
    verifyEq(b.liveLine, "  acme ··· [compile] FindSourceFiles [3 files] (0.0sec)")
  }

  Void testClean()
  {
    // groups clean every pod, then compile every pod; one row per
    // pod and target, with target columns padded to line up
    buf := Buf()
    b := Builder([`/x/build.fan`.toFile], ["acme", "beta"], ["clean", "compile"], false, false, buf.out)
    b.fixedNow = 0ms
    parse(b,
      "clean [acme]
         Delete [file:/x/lib/fan/acme.pod]")
    verifyEq(b.liveLine, "  acme ··· [clean]   Delete [file:/x/lib/fan/acme.pod] (0.0sec)")
    parse(b,
      "clean [beta]
       compile [acme]
         Compile [acme]
       compile [beta]
         Compile [beta]
       BUILD SUCCESS [12ms]!")
    verifyEq(b.summary(0), 0)
    lines := buf.flip.readAllLines
    verifyEq(lines[0..3],
      ["  acme ··· [clean]   ok (0ms)",
       "  beta ··· [clean]   ok (0ms)",
       "  acme ··· [compile] ok (0ms)",
       "  beta ··· [compile] ok (0ms)"])
    verify(lines[-1].startsWith("✓ Cleaned and built 2 pods in "))
  }

  Void testTarget()
  {
    // clean on its own gets rows
    buf := Buf()
    b := Builder([`/x/build.fan`.toFile], ["acme"], ["clean"], false, false, buf.out)
    b.fixedNow = 0ms
    parse(b,
      "clean [acme]
         Delete [file:/x/lib/fan/acme.pod]
       BUILD SUCCESS [3ms]!")
    verifyEq(b.summary(0), 0)
    lines := buf.flip.readAllLines
    verifyEq(lines[0], "  acme ··· [clean] ok (0ms)")
    verify(lines[-1].startsWith("✓ Cleaned 1 pod in "))

    // other targets are named in the summary
    buf = Buf()
    b = Builder([`/x/build.fan`.toFile], ["acme"], ["dist"], false, false, buf.out)
    b.fixedNow = 0ms
    parse(b, "dist [acme]\nBUILD SUCCESS [3ms]!")
    verifyEq(b.summary(0), 0)
    verify(buf.flip.readAllLines[-1].startsWith("✓ Ran dist on 1 pod in "))
  }

  Void testFindPod()
  {
    verifyEq(Builder.findPod(FxPod(), "fxPod")?.podName, "fxPod")
    verifyNull(Builder.findPod(FxPod(), "nope"))
  }

  Void testSearchPod()
  {
    repo := tempDir + `repo/`
    (repo + `.git/`).create
    acme := repo + `src/a/acme/`
    writeScript(acme, "acme")
    writeScript(repo + `src/.hidden/acme/`, "acme")
    writeScript(repo + `src/node_modules/acme/`, "acme")
    writeScript(repo + `var/acme/`, "acme")
    writeScript(repo + `src/b/beta/`, "betaWeb")
    (repo + `src/c/acme/`).create

    // repo root is the nearest dir with a .git dir, or a .git file
    // as used by worktrees and submodules
    verifyEq(Builder.repoRoot(acme), repo)
    sub := repo + `sub/`
    sub.plus(`.git`, false).out.print("gitdir: ../.git/modules/sub").close
    (sub + `x/`).create
    verifyEq(Builder.repoRoot(sub + `x/`), sub)

    // only dirs named for the pod with a build.fan, skipping hidden
    // dirs and node_modules; only src/ is searched when there is one
    verifyEq(Builder.podDirs(repo + `src/`, "acme"), [acme])
    verifyEq(Builder.searchPod(repo, "acme")?.scriptFile, acme + `build.fan`)

    // nothing is found without src/
    flat := tempDir + `flat/`
    writeScript(flat + `acme/`, "acme")
    verifyNull(Builder.searchPod(flat, "acme"))

    // dir name must match the pod name it builds
    verifyNull(Builder.searchPod(repo, "beta"))
    verifyNull(Builder.searchPod(repo, "nope"))

    // more than one match is an error
    writeScript(repo + `src/d/acme/`, "acme")
    verifyErr(ArgErr#) { Builder.searchPod(repo, "acme") }
  }

  private Void writeScript(File dir, Str pod)
  {
    (dir + `build.fan`).out.print(
      "using build
       class Build : BuildPod { new make() { podName = \"$pod\"; summary = \"\" } }").close
  }

  private Void parse(Builder b, Str s) { s.splitLines.each |line| { b.parseLine(line) } }
}
