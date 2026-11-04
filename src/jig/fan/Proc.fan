//
// Copyright (c) 2026, Novant LLC
// Licensed under the MIT License
//
// History:
//   26 Oct 2026  Andy Frank  Creation
//

using concurrent

*************************************************************************
** Proc
*************************************************************************

** Process utilities.
const class Proc
{
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

  ** Path to 'fan' launcher for current runtime.
  static Str[] fan()
  {
    path := (Env.cur.homeDir + `bin/fan`).osPath
    return Env.cur.os == "win32" ? ["cmd", "/C", path] : [path]
  }
}
