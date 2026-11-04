//
// Copyright (c) 2026, Novant LLC
// Licensed under the MIT License
//
// History:
//   26 Oct 2026  Andy Frank  Creation
//   4 Nov 2026   Andy Frank  Rework as instance API with Style
//

using [java] java.lang::System as JavaSystem

*************************************************************************
** Term
*************************************************************************

**
** Term is the output API for jig.  Code should style text through
** Term instead of raw escape codes, so styling is dropped when
** output is not a terminal.  Cursor control for the live status
** bar is owned by `LiveRegion`.
**
** Style methods ('ok', 'err', 'dim', ...) return a styled 'Str' to
** compose a line:
**
**   term := Term()
**   out.printLine("Built " + term.accent(pod) + " " + term.dim("(2.3sec)"))
**
class Term
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  **
  ** Construct a Term writing to 'stdout' and 'stderr'.
  **
  ** If 'color' is null, color is enabled when 'isTty' and 'NO_COLOR'
  ** is not set, or when 'FORCE_COLOR' is set.  If 'live' is null,
  ** a `LiveRegion` redraws in place when 'isTty'.
  **
  new make(OutStream stdout := Env.cur.out, OutStream stderr := Env.cur.err,
           Bool? color := null, Bool? live := null)
  {
    this.stdout = stdout
    this.stderr = stderr
    this.color  = color ?: detectColor
    this.live   = live ?: isTty
  }

  ** Stdout stream.
  OutStream stdout { private set }

  ** Stderr stream.
  OutStream stderr { private set }

  ** Is styled output enabled.
  const Bool color

  ** Does a `LiveRegion` redraw in place.
  const Bool live

  ** Terminal width in columns, or 80 if not 'live'.
  Int width()
  {
    if (widthRef == null) widthRef = live ? detectWidth : 80
    return widthRef
  }

//////////////////////////////////////////////////////////////////////////
// Style
//////////////////////////////////////////////////////////////////////////

  ** Apply 'style' to 'text', or return plain text if color is
  ** disabled.  Styled text nested inside 'text' is left as-is.
  Str style(Style style, Obj? text)
  {
    s := text?.toStr ?: "null"
    if (!color || style.sgr.isEmpty) return s
    return style.code + s + Style.reset
  }

  Str bold(Obj? text)   { style(Style.bold,   text) }
  Str dim(Obj? text)    { style(Style.muted,  text) }
  Str ok(Obj? text)     { style(Style.ok,     text) }
  Str err(Obj? text)    { style(Style.err,    text) }
  Str warn(Obj? text)   { style(Style.warn,   text) }
  Str accent(Obj? text) { style(Style.accent, text) }
  Str info(Obj? text)   { style(Style.info,   text) }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  ** Remove ANSI escape sequences from 's'.
  static Str strip(Str s)
  {
    if (!s.contains("\u001b")) return s
    buf := StrBuf()
    i := 0
    while (i < s.size)
    {
      c := s[i]
      if (c == 0x1b && i+1 < s.size && s[i+1] == '[')
      {
        // skip CSI params until final byte in 0x40..0x7e
        i += 2
        while (i < s.size && (s[i] < 0x40 || s[i] > 0x7e)) i++
        i++
        continue
      }
      buf.addChar(c)
      i++
    }
    return buf.toStr
  }

  ** Number of visible chars in 's' excluding escape sequences.
  static Int visibleSize(Str s) { strip(s).size }

  ** Is stdout an interactive terminal.
  static Bool isTty()
  {
    if (Env.cur.vars["CI"] != null) return false
    if (Env.cur.vars["TERM"] == "dumb") return false
    return JavaSystem.console != null
  }

  ** Default color setting from the environment; see `make`.
  static Bool detectColor()
  {
    vars := Env.cur.vars
    if (vars["NO_COLOR"]?.isEmpty == false) return false
    if (vars["FORCE_COLOR"]?.isEmpty == false) return true
    return isTty
  }

  ** Terminal width from 'COLUMNS' or 'stty', or 80 if unknown.
  static Int detectWidth()
  {
    cols := Env.cur.vars["COLUMNS"]?.toInt(10, false)
    if (cols != null) return cols
    try
    {
      Str? size
      Proc.exec(["sh", "-c", "stty size < /dev/tty"], |s| { size = s }) |->Bool| { size != null }
      cols = size?.trim?.split(' ')?.last?.toInt(10, false)
    }
    catch (Err e) {}
    return cols != null && cols > 0 ? cols : 80
  }

  private Int? widthRef
}
