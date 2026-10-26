//
// Copyright (c) 2026, Novant LLC
// Licensed under the MIT License
//
// History:
//   26 Oct 2026  Andy Frank  Creation
//

using build

*************************************************************************
** JigBuild
*************************************************************************

** JigBuild runs jig from inside a build script, so output gets the
** status bar and colors without spawning 'fan jig'.  Tests still run
** in a separate 'fant' process.
**
**   // BuildPod
**   override Void test() { JigBuild.test(this) }
**
**   // BuildGroup
**   @Target Void full()
**   {
**     runOnChildren("clean")
**     runOnChildren("compile")
**     JigBuild.test(this)
**   }
**
const class JigBuild
{
  ** Run jig on 'targets', or on every pod in 'script' if null.
  ** Throws FatalBuildErr if any test fails.
  static Void test(BuildScript script, Str[]? targets := null, Bool quiet := false)
  {
    targets = targets ?: podNames(script)
    names := targets.join(", ")
    script.log.info("jig [$names]")

    Str[]? tests
    try tests = Resolver.resolve(targets)
    catch (ArgErr e) throw script.fatal(e.msg)
    if (tests.isEmpty) { script.log.info("  no tests found"); return }

    if (Runner(targets, tests, quiet).run != 0) throw script.fatal("jig tests failed")
  }

  ** Pod names of all BuildPod scripts under 'script' (recursive).
  static Str[] podNames(BuildScript script)
  {
    if (script is BuildPod) return Str[((BuildPod)script).podName]
    if (script is BuildGroup) return ((BuildGroup)script).children.map |c| { podNames(c) }.flatten
    return Str[,]
  }
}
