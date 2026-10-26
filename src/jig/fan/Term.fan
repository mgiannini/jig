//
// Copyright (c) 2026, Novant LLC
// Licensed under the MIT License
//
// History:
//   26 Oct 2026  Andy Frank  Creation
//

using [java] java.lang::System as JavaSystem
using concurrent

*************************************************************************
** Term
*************************************************************************

** Terminal and process utilities.
const class Term
{
  ** Is stdout an interactive terminal.
  static Bool isTty()
  {
    if (Env.cur.vars["CI"] != null) return false
    if (Env.cur.vars["TERM"] == "dumb") return false
    return JavaSystem.console != null
  }

  ** Terminal width in columns, or 80 if unknown.
  static Int width()
  {
    cols := Env.cur.vars["COLUMNS"]?.toInt(10, false)
    if (cols != null) return cols
    try
    {
      Str? size
      exec(["sh", "-c", "stty size < /dev/tty"], |s| { size = s }) |->Bool| { size != null }
      cols = size?.trim?.split(' ')?.last?.toInt(10, false)
    }
    catch (Err e) {}
    return cols != null && cols > 0 ? cols : 80
  }

  ** Run process and deliver each line of merged stdout/stderr to
  ** 'onLine'; returns exit code.  'Process.join' does not wait for
  ** the output pump thread, so after exit we wait until 'isDone'
  ** returns true, or output has been quiet for 250ms.
  static Int exec(Str[] cmd, |Str| onLine, |->Bool|? isDone := null)
  {
    out  := LineOutStream(onLine)
    proc := Process(cmd) { it.out = out; it.mergeErr = true }
    exit := proc.run.join
    while (isDone == null || !isDone())
    {
      if (Duration.nowTicks - out.lastWrite > 250ms.ticks) break
      Actor.sleep(5ms)
    }
    out.close
    return exit
  }

  ** Path to 'fant' launcher for current runtime.
  static Str[] fant()
  {
    path := (Env.cur.homeDir + `bin/fant`).osPath
    return Env.cur.os == "win32" ? ["cmd", "/C", path] : [path]
  }

  static const Str clearLine := "\r\u001b[2K"
  static const Str upClearLine := "\u001b[1A\u001b[2K"
  static const Str reset     := "\u001b[0m"
  static const Str bold      := "\u001b[1m"
  static const Str dim       := "\u001b[2m"
  static const Str red       := "\u001b[31m"
  static const Str green     := "\u001b[32m"
  static const Str magenta   := "\u001b[35m"
}
