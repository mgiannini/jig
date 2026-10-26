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

  @Opt { help = "test all pods in workDir lib/fan/" }
  Bool work

  @Arg { help = "<pod>, <pod>::<Type>, or <pod>::<Type>.<method>" }
  Str[] targets := [,]

  override Int run()
  {
    if (work)
    {
      // without a workenv workDir is homeDir; refuse to test the whole distro
      if (Env.cur.workDir.normalize == Env.cur.homeDir.normalize)
      {
        echo("ERR: -work requires a workenv (fan.props)")
        return 1
      }
      targets = workPods(Env.cur.workDir)
    }

    if (targets.isEmpty) return usage
    // TODO: resolve targets, spawn fant, render status bar
    echo("jig: ${targets}")
    return 0
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