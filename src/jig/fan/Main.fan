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

** Jig command line entry point:
**
**   jig test <targets>* [-q] [-es|-js]
**   jig build [<pod> | <file.fan>]* [-c] [-f] [-t <target>] [-q]
**
class Main : AbstractMain
{
  @Opt { help = "test: new ECMA JavaScript environment" }
  Bool es

  @Opt { help = "test: legacy JavaScript environment" }
  Bool js

  ** Field names are single letters so AbstractMain gives '-c';
  ** the '-clean' alias matches '--clean' after the leading dash.
  @Opt { help = "build: clean only"; aliases = ["-clean"] }
  Bool c

  @Opt { help = "build: clean, compile, then test"; aliases = ["-full"] }
  Bool f

  @Opt { help = "build: run build script target instead of compile"; aliases = ["-target"] }
  Str? t

  @Opt { help = "only print failures and status bar"; aliases = ["-quiet"] }
  Bool q

  @Arg { help = "test|build followed by its targets" }
  Str[] args := [,]

  override Int usage(OutStream out := Env.cur.out)
  {
    out.printLine(
      "Usage:
         jig test <targets>* [options]
         jig build [<pod> | <file.fan>]* [options]

       Test targets:
         <pod>, <pod>::<Type>, or <pod>::<Type>.<method>;
         with no targets test all pods in workDir lib/fan/

       Test options:
         -es           test new ECMA JavaScript environment
         -js           test legacy JavaScript environment

       Build targets:
         <pod> in the current repo, or a build script path;
         with no targets build ./build.fan or <workDir>/src/build.fan

       Build options:
         Compiles by default; or pick one of:
         -c, --clean   clean only
         -f, --full    clean, compile, then test
         -t, --target <target>
                       run this build script target

       Options:
         -q, --quiet   only print failures, status bar, and summary")
    return 1
  }

  ** Reject unknown options up front; AbstractMain only warns and
  ** carries on, so a typo like '-clean' would silently be ignored.
  override Bool parseArgs(Str[] toks)
  {
    names := Str:Str[:]
    optFields.each |f|
    {
      n := f.name.endsWith("Opt") ? f.name[0..<-3] : f.name
      names[n] = n
      ((Opt)f.facet(Opt#)).aliases.each |a| { names[a] = a }
    }
    badOpt = toks.find |tok| { tok.startsWith("-") && tok.size > 1 && names[tok[1..-1]] == null }
    if (badOpt != null) return true
    return super.parseArgs(toks)
  }

  private Str? badOpt

  override Int run()
  {
    if (badOpt != null) { echo("ERR: unknown option '$badOpt'"); return 1 }
    if (args.isEmpty) return usage
    cmd  := args.first
    rest := args[1..-1]
    switch (cmd)
    {
      case "test":  return test(rest)
      case "build": return build(rest)
    }
    echo("ERR: unknown command '$cmd'; expected 'test' or 'build'")
    return 1
  }

  ** 'jig test'
  private Int test(Str[] targets)
  {
    if (c) return optErr("-c", "test")
    if (f) return optErr("-f", "test")
    if (t != null) return optErr("-t", "test")

    // no targets tests every pod built into the workenv
    if (targets.isEmpty)
    {
      // without a workenv workDir is homeDir; refuse to test the whole distro
      if (Env.cur.workDir.normalize == Env.cur.homeDir.normalize)
      {
        echo("ERR: no targets; 'jig test' with no targets requires a workenv (fan.props)")
        return 1
      }
      targets = workPods(Env.cur.workDir)
      if (targets.isEmpty)
      {
        echo("ERR: no pods found in ${Env.cur.workDir.osPath}/lib/fan/")
        return 1
      }
    }

    // js/es use their own runners with a different output format
    if (es) return Runner.passthrough("-es", targets)
    if (js) return Runner.passthrough("-js", targets)

    Str[]? tests
    try tests = Resolver.resolve(targets)
    catch (ArgErr e) { echo("ERR: $e.msg"); return 1 }
    if (tests.isEmpty) { echo("ERR: no tests found"); return 1 }

    return Runner(targets, tests, q).run
  }

  ** 'jig build'
  private Int build(Str[] targets)
  {
    if (es) return optErr("-es", "build")
    if (js) return optErr("-js", "build")
    // AbstractMain only logs a missing value; don't fall back to compile
    if (t == null && Env.cur.args.any { it == "-t" || it == "--target" })
    {
      echo("ERR: -t requires a target name")
      return 1
    }
    if ([c, f, t != null].findAll { it }.size > 1)
    {
      echo("ERR: use only one of -c, -f, or -t")
      return 1
    }
    return Builder.main(targets, q, c, f, t)
  }

  private Int optErr(Str opt, Str cmd)
  {
    echo("ERR: $opt is not a '$cmd' option")
    return 1
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
