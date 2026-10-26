//
// Copyright (c) 2026, Novant LLC
// Licensed under the MIT License
//
// History:
//   26 Oct 2026  Andy Frank  Creation
//

using concurrent

*************************************************************************
** LineOutStream
*************************************************************************

** OutStream that splits written bytes into UTF-8 lines and
** delivers each to a callback.  Used to capture Process output.
class LineOutStream : OutStream
{
  new make(|Str| onLine) : super(null) { this.onLine = onLine }

  ** Ticks of last write, safe to read from any thread.
  Int lastWrite() { lastWriteRef.val }

  override This write(Int b)
  {
    lastWriteRef.val = Duration.nowTicks
    if (b == '\n') emit
    else buf.write(b)
    return this
  }

  override This writeBuf(Buf b, Int n := b.remaining)
  {
    n.times { write(b.read) }
    return this
  }

  override This flush() { this }

  ** Deliver any trailing partial line.
  override Bool close()
  {
    if (buf.size > 0) emit
    return true
  }

  private Void emit()
  {
    line := buf.flip.readAllStr(false)
    buf.clear
    if (line.endsWith("\r")) line = line[0..-2]
    onLine(line)
  }

  private |Str| onLine
  private Buf buf := Buf()
  private const AtomicInt lastWriteRef := AtomicInt(Duration.nowTicks)
}
