//
// Copyright (c) 2026, Novant LLC
// Licensed under the MIT License
//
// History:
//   26 Oct 2026  Andy Frank  Creation
//

using util

*************************************************************************
** Main
*************************************************************************

** Jig command line entry point.
class Main : AbstractMain
{
  @Opt { help = "test new ECMA JavaScript environment" }
  Bool es

  @Opt { help = "test legacy JavaScript environment" }
  Bool js

  ** Field names are single letters so AbstractMain gives '-w';
  ** the '-work' alias matches '--work' after the leading dash.
  @Opt { help = "test all pods in workDir lib/fan/"; aliases = ["-work"] }
  Bool w

  @Opt { help = "only print failures and status bar"; aliases = ["-quiet"] }
  Bool q

  @Arg { help = "<pod>, <pod>::<Type>, or <pod>::<Type>.<method>" }
  Str[] targets := [,]

  override Int run()
  {
    if (w)
    {
      // without a workenv workDir is homeDir; refuse to test the whole distro
      if (Env.cur.workDir.normalize == Env.cur.homeDir.normalize)
      {
        echo("ERR: -w requires a workenv (fan.props)")
        return 1
      }
      targets = workPods(Env.cur.workDir)
      if (targets.isEmpty)
      {
        echo("ERR: no pods found in ${Env.cur.workDir.osPath}/lib/fan/")
        return 1
      }
    }

    if (targets.isEmpty) return usage

    // js/es use their own runners with a different output format
    if (es) return Runner.passthrough("-es", targets)
    if (js) return Runner.passthrough("-js", targets)

    Str[]? tests
    try tests = Resolver.resolve(targets)
    catch (ArgErr e) { echo("ERR: $e.msg"); return 1 }
    if (tests.isEmpty) { echo("ERR: no tests found"); return 1 }

    return Runner(targets, tests, q).run
  }

  ** Return sorted names of all pods under '<dir>/lib/fan/'.
  static Str[] workPods(File dir)
  {
    lib := dir + `lib/fan/`
    if (!lib.exists) return Str[,]
    return lib.list.findAll |f| { !f.isDir && f.ext == "pod" }
      .map |f->Str| { f.basename }
      .sort
  }
}