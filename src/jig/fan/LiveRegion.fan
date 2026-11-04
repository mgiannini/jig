//
// Copyright (c) 2026, Novant LLC
// Licensed under the MIT License
//
// History:
//   4 Nov 2026  Andy Frank  Creation
//

using concurrent

*************************************************************************
** LiveRegion
*************************************************************************

**
** LiveRegion is a block of lines redrawn in place at the bottom of
** the terminal, such as a live line above the status bar:
**
**     FooTest ··· [1/4]  testB (0.3sec)
**
**   TEST [██▏░░░] 11% 1/9 | ✓ 1 0.3sec | acme [1/9]
**
** Lines printed with `printAbove` scroll above it.  The region is
** re-rendered by calling 'render' on every redraw, and a ticker
** redraws it every 100ms so elapsed times keep moving.
**
** This class owns all cursor control codes; nothing else should
** emit them.  If the term is not 'live', lines are printed as-is
** and nothing is drawn.
**
internal class LiveRegion
{
  ** Create region on 'term.stdout'; 'render' returns the lines of
  ** the region top to bottom, and is called while holding the lock.
  new make(Term term, |->Str[]| render)
  {
    this.out    = term.stdout
    this.live   = term.live
    this.render = render
  }

  ** Print lines above the region.
  Void printAbove(Str[] lines)
  {
    if (!live) { lines.each |s| { out.printLine(s) }; return }
    lock.lock
    try
    {
      // one write so the console never paints a partial frame
      buf := StrBuf().add(erase)
      lines.each |s| { buf.add(s).add("\n") }
      write(buf.add(frame).toStr)
    }
    finally lock.unlock
  }

  ** Redraw region in place; called from both the caller's thread
  ** and the ticker, so serialized with 'lock'.
  Void redraw()
  {
    if (!live) return
    lock.lock
    try
    {
      if (running.val) write(erase + frame)
    }
    finally lock.unlock
  }

  ** Start ticker to redraw every 100ms.
  Void start()
  {
    if (!live) return
    pool = ActorPool { it.name = "jigTicker"; it.maxThreads = 1 }
    self := Unsafe(this)
    flag := this.running
    Actor(pool) |->Obj?|
    {
      while (flag.val) { Actor.sleep(100ms); ((LiveRegion)self.val).redraw }
      return null
    }.send(null)
  }

  ** Stop ticker and erase region; later 'printAbove' calls print
  ** lines without drawing it again.
  Void stop()
  {
    running.val = false
    pool?.stop?.join(1sec)
    if (live) out.print(erase).flush
  }

  ** Region lines joined for drawing, or empty once stopped.
  private Str frame()
  {
    if (!running.val) return ""
    lines := render()
    drawn = lines.size - 1
    return lines.join("\n")
  }

  ** Escape sequence to clear the region, leaving the cursor
  ** where it started.
  private Str erase()
  {
    s := clearLine + upClearLine * drawn
    drawn = 0
    return s
  }

  ** Write frame 's' as one encoded buffer and flush.  Writing char
  ** by char lets 'System.out' split a frame on newlines and its 128
  ** byte buffer, which Windows consoles paint as separate partial
  ** frames.  The frame is also wrapped in synchronized output (DEC
  ** mode 2026) so terminals that support it paint it at once;
  ** others ignore the unknown mode.
  private Void write(Str s)
  {
    out.writeBuf(Buf().print(syncBegin).print(s).print(syncEnd).flip).flush
  }

  private static const Str clearLine   := "\r\u001b[2K"
  private static const Str upClearLine := "\u001b[1A\u001b[2K"
  private static const Str syncBegin   := "\u001b[?2026h"
  private static const Str syncEnd     := "\u001b[?2026l"

  private OutStream out
  private const Bool live
  private |->Str[]| render
  private Int drawn
  private ActorPool? pool
  private const Lock lock := Lock.makeReentrant
  private const AtomicBool running := AtomicBool(true)
}
