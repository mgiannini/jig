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
    done := passed + failed
    pct  := "${(total <= 0 ? 0 : (done * 100 / total).min(100))}%"
    bar  := bar(done, total)
    c    := failed > 0 ? Term.red : Term.green
    sep  := color ? Term.dim + groupSep + Term.reset : groupSep

    // [plain, colored] pairs so we can measure before coloring
    pre  := mode == null ? ["", ""] : ["$mode ", Term.bold + mode + Term.reset + " "]
    head := [pre[0] + "[$bar] $pct $done/$total",
             pre[1] + "[" + c + bar + Term.reset + "] " + Term.bold + pct + Term.reset + " $done/$total"]
    res  := failed > 0
      ? ["✓ $passed ✗ $failed", Term.green + "✓ $passed" + Term.reset + " " + Term.red + "✗ $failed" + Term.reset]
      : ["✓ $passed", Term.green + "✓ $passed" + Term.reset]
    time := " " + fmtBarDur(elapsed)

    // drop time if even the base line doesn't fit
    max  := width - 1
    if (head[0].size + groupSep.size + res[0].size + time.size > max) time = ""
    base := head[0].size + groupSep.size + res[0].size + time.size

    s := StrBuf()
    s.add(color ? head[1] : head[0]).add(sep).add(color ? res[1] : res[0]).add(time)

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
