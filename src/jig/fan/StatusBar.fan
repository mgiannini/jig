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

  ** Render status line to fit within 'width' columns:
  **
  **   TEST [█▏░░░░] 6% 80/1324 | ✓ 80 4.8sec | core [79/149]
  **
  ** The 'mode' prefix such as 'TEST' or 'BUILD' is omitted if null.
  ** If the line is too wide the label is clipped from the left or
  ** dropped first, then the time.
  static Str render(Int total, Int passed, Int failed, Str? label,
                    Duration elapsed, Int width, Bool color := true, Str? mode := null)
  {
    t    := Term(Env.cur.out, Env.cur.err, color, false)
    done := passed + failed
    pct  := "${(total <= 0 ? 0 : (done * 100 / total).min(100))}%"
    bar  := t.style(failed > 0 ? Style.err : Style.ok, bar(done, total))
    pre  := mode == null ? "" : t.bold(mode) + " "
    head := pre + "[$bar] " + t.bold(pct) + " $done/$total"
    res  := t.ok("✓ $passed") + (failed > 0 ? " " + t.err("✗ $failed") : "")
    time := " " + fmtBarDur(elapsed)

    // drop time if even the base line doesn't fit
    max  := width - 1
    base := Term.visibleSize(head) + groupSep.size + Term.visibleSize(res)
    if (base + time.size > max) time = ""
    base += time.size

    sep := t.dim(groupSep)
    s   := StrBuf()
    s.add(head).add(sep).add(res).add(time)

    // clip label from the left so the end stays visible, or drop it
    // if too little room is left to be useful
    avail := max - base - groupSep.size
    if (label != null && avail >= 12)
      s.add(sep).add(label.size <= avail ? label : "…" + label[-(avail-1)..-1])
    return s.toStr
  }

  ** Separator between status bar groups.
  private static const Str groupSep := " | "

  ** Bar of 'barSize' cells with eighth-cell partial blocks.
  static Str bar(Int done, Int total)
  {
    eighths := total <= 0 ? 0 : (done * barSize * 8 / total).min(barSize * 8)
    full := eighths / 8
    rem  := eighths % 8
    s := StrBuf()
    full.times { s.add("█") }
    if (rem > 0) s.add("▏▎▍▌▋▊▉"[rem-1].toChar)
    (barSize - full - (rem > 0 ? 1 : 0)).times { s.add("░") }
    return s.toStr
  }

  ** Format duration as '12.3sec', or '2min 5sec' once past 59sec.
  static Str fmtDur(Duration d)
  {
    ms := d.toMillis.max(0)
    if (ms < 60_000) return "${ms / 1000}.${ms % 1000 / 100}sec"
    return fmtMin(ms)
  }

  ** Format status bar clock as '12.3sec', then '3min 10.4sec';
  ** tenths are truncated so the clock never jumps ahead.
  static Str fmtBarDur(Duration d)
  {
    ms  := d.toMillis.max(0)
    rem := ms % 60_000
    sec := "${rem / 1000}.${rem % 1000 / 100}sec"
    return ms < 60_000 ? sec : "${ms / 60_000}min $sec"
  }

  ** Format duration as '4900ms' under 5sec, '7.2sec' under 1min,
  ** then '2min 5sec'; rounded to nearest tenth or whole second.
  static Str fmtDurMs(Duration d)
  {
    ms := d.toMillis.max(0)
    if (ms < 5_000) return "${ms}ms"
    tenths := (ms + 50) / 100
    if (tenths < 600) return "${tenths / 10}.${tenths % 10}sec"
    return fmtMin(ms)
  }

  ** Format as minutes and seconds rounded to nearest second.
  private static Str fmtMin(Int ms)
  {
    secs := (ms + 500) / 1000
    return "${secs / 60}min ${secs % 60}sec"
  }
}
