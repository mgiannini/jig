//
// Copyright (c) 2026, Novant LLC
// Licensed under the MIT License
//
// History:
//   4 Nov 2026  Andy Frank  Creation
//

*************************************************************************
** Style
*************************************************************************

**
** Style is an ANSI SGR text style.  This is the single place
** colors are defined; code should use the semantic roles
** ('ok', 'err', 'warn', ...) so the palette can change in one spot.
** Styles combine with '+':
**
**   Style.bold + Style.err
**
** Styles are applied with `Term.style` which drops them when color
** output is disabled.
**
const class Style
{
  ** Construct with SGR parameter string such as '"1"' or '"1;31"'.
  new make(Str sgr) { this.sgr = sgr }

  ** SGR parameter string, empty for `none`.
  const Str sgr

  ** Escape sequence to enable this style.
  Str code() { sgr.isEmpty ? "" : "\u001b[${sgr}m" }

  ** Combine two styles.
  @Operator Style plus(Style that)
  {
    if (sgr.isEmpty) return that
    if (that.sgr.isEmpty) return this
    return Style("$sgr;$that.sgr")
  }

  override Str toStr() { sgr }

  override Bool equals(Obj? that) { (that as Style)?.sgr == sgr }

  override Int hash() { sgr.hash }

//////////////////////////////////////////////////////////////////////////
// Palette
//////////////////////////////////////////////////////////////////////////

  ** No style.
  static const Style none := Style("")

  ** Bold or increased intensity.
  static const Style bold := Style("1")

  ** Dim or decreased intensity.
  static const Style dim := Style("2")

  ** Underline.
  static const Style underline := Style("4")

  static const Style red     := Style("31")
  static const Style green   := Style("32")
  static const Style yellow  := Style("33")
  static const Style blue    := Style("34")
  static const Style magenta := Style("35")
  static const Style cyan    := Style("36")

//////////////////////////////////////////////////////////////////////////
// Roles
//////////////////////////////////////////////////////////////////////////

  ** Success: passed, done, ok.
  static const Style ok := green

  ** Failure or error.
  static const Style err := red

  ** Warning or needs attention.
  static const Style warn := yellow

  ** Highlight names, counts, and other key values.
  static const Style accent := magenta

  ** Informational, such as paths and URIs.
  static const Style info := cyan

  ** Secondary text, such as timings and detail lines.
  static const Style muted := dim

  ** Reset all styles.
  static const Str reset := "\u001b[0m"
}
