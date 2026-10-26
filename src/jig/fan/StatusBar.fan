//
// Copyright (c) 2026, Novant LLC
// Licensed under the MIT License
//
// History:
//   26 Oct 2026  Andy Frank  Creation
//

*************************************************************************
** StatusBar
*************************************************************************

** StatusBar renders the single line progress display.
const class StatusBar
{
  ** Width of the progress bar in cells.
  static const Int barSize := 20

  ** Render status line to fit within 'width' columns.
  static Str render(Int total, Int passed, Int failed, Str? current,
                    Duration elapsed, Int width, Bool color := true)
  {
    done   := passed + failed
    filled := total <= 0 ? 0 : (done * barSize / total).min(barSize)
    bar    := Str.spaces(filled).replace(" ", "█") + Str.spaces(barSize - filled).replace(" ", "░")

    // build plain prefix first so we know how much room is left
    count := "$done/$total"
    pass  := "✓ $passed"
    fail  := failed > 0 ? "  ✗ $failed" : ""
    time  := fmtDur(elapsed)
    plain := "[$bar] $count  $pass$fail  $time"

    // truncate from the left so the method name stays visible
    name  := ""
    avail := width - 1 - plain.size - 2
    if (current != null && avail >= 8)
      name = current.size <= avail ? current : "…" + current[-(avail-1)..-1]

    if (!color) return name.isEmpty ? plain : "$plain  $name"

    c := failed > 0 ? Term.red : Term.green
    s := StrBuf()
    s.add("[").add(c).add(bar).add(Term.reset).add("] ")
    s.add(Term.bold).add(count).add(Term.reset).add("  ")
    s.add(Term.green).add(pass).add(Term.reset)
    if (failed > 0) s.add("  ").add(Term.red).add("✗ $failed").add(Term.reset)
    s.add("  ").add(Term.dim).add(time).add(Term.reset)
    if (!name.isEmpty) s.add("  ").add(name)
    return s.toStr
  }

  ** Format duration as '12.3sec', or '2min 5sec' once past 59sec.
  static Str fmtDur(Duration d)
  {
    ms := d.toMillis.max(0)
    if (ms < 60_000) return "${ms / 1000}.${ms % 1000 / 100}sec"
    return fmtMin(ms)
  }

  ** Format duration as '4900ms' under 5sec, '6sec' under 1min,
  ** then '2min 5sec'; seconds are rounded to nearest whole.
  static Str fmtDurMs(Duration d)
  {
    ms := d.toMillis.max(0)
    if (ms < 5_000) return "${ms}ms"
    secs := (ms + 500) / 1000
    if (secs < 60) return "${secs}sec"
    return fmtMin(ms)
  }

  ** Format as minutes and seconds rounded to nearest second.
  private static Str fmtMin(Int ms)
  {
    secs := (ms + 500) / 1000
    return "${secs / 60}min ${secs % 60}sec"
  }
}
