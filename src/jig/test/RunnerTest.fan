//
// Copyright (c) 2026, Novant LLC
// Licensed under the MIT License
//
// History:
//   26 Oct 2026  Andy Frank  Creation
//

*************************************************************************
** RunnerTest
*************************************************************************

class RunnerTest : Test
{
  Void testTrimTrace()
  {
    trace :=
      "sys::TestErr: Test failed: 1 != 2
         fan.sys.Test.err (Test.java:239)
         fan.sys.Test.verifyEq (Test.java:93)
         acme::FooTest.helper (FooTest.fan:20)
         acme::FooTest.testB (FooTest.fan:12)
         jdk.internal.reflect.NativeMethodAccessorImpl.invoke0 (NativeMethodAccessorImpl.java)
         fan.sys.Method.invoke (Method.java:573)
         acme::NotMine.frame (X.fan:1)
         util::TestRunner.runMethod (TestRunner.fan:220)
         11 More...
         Cause:
           sys::IOErr: disk full
             acme::Disk.write (Disk.fan:5)
             java.lang.reflect.Method.invoke (Method.java:566)
             util::TestRunner.main (TestRunner.fan:80)".splitLines

    verifyEq(Runner.trimTrace(trace),
      ["sys::TestErr: Test failed: 1 != 2",
       "  acme::FooTest.helper (FooTest.fan:20)",
       "  acme::FooTest.testB (FooTest.fan:12)",
       "  Cause:",
       "    sys::IOErr: disk full",
       "      acme::Disk.write (Disk.fan:5)"])
  }

  Void testDefault()
  {
    buf := Buf()
    tests := [
      "acme::FooTest.testA", "acme::FooTest.testB",
      "acme::LongNameTest.testC",
      "beta::BarTest.testD",
    ]
    r := Runner(["acme", "beta"], tests, false, false, buf.out)
    r.fixedNow = 0ms
    r.onStart("acme::FooTest.testA")
    r.fixedNow = 1sec
    r.onPass("acme::FooTest.testA", 3)
    r.onStart("acme::FooTest.testB")
    r.fixedNow = 2500ms
    r.onFail("acme::FooTest.testB", ["echo"], ["sys::Err: boom"])
    r.onStart("acme::LongNameTest.testC")
    r.fixedNow = 64400ms  // 61.9sec rounds up
    r.onPass("acme::LongNameTest.testC", 1)
    r.onStart("beta::BarTest.testD")
    r.onPass("beta::BarTest.testD", 1)
    verifyEq(buf.flip.readAllLines,
      ["acme",
       "  FooTest       [1/2] fail (2500ms)",
       "    FAIL: testB",
       "      | echo",
       "      sys::Err: boom",
       "  LongNameTest  [1/1] pass (1min 2sec)",
       "",
       "beta",
       "  BarTest  [1/1] pass (0ms)"])
  }

  Void testDefaultCutShort()
  {
    // fant dies mid-type; next type or end of run flushes it
    buf := Buf()
    r := Runner(["acme"], ["acme::FooTest.testA", "acme::FooTest.testB"], false, false, buf.out)
    r.fixedNow = 0ms
    r.onStart("acme::FooTest.testA")
    r.onPass("acme::FooTest.testA", 3)
    verifyEq(buf.flip.readAllLines, ["acme"])
    r.onStart("acme::Other.testX")
    verifyEq(buf.seek(0).readAllLines, ["acme", "  FooTest  [1/2] fail (0ms)"])
  }

  Void testLiveLine()
  {
    tests := ["acme::FooTest.testA", "acme::FooTest.testB", "acme::FooTest.testC",
              "acme::LongNameTest.testD"]
    r := Runner(["acme"], tests, false, false, Buf().out)
    r.fixedNow = 0ms
    verifyEq(r.liveLine, null)

    r.onStart("acme::FooTest.testA")
    verifyEq(r.liveLine, "  FooTest       [0/3]  testA (0.0sec)")
    r.onFail("acme::FooTest.testA", [,], ["sys::Err: boom"])
    r.fixedNow = 10sec
    r.onStart("acme::FooTest.testB")
    verifyEq(r.liveLine, "  FooTest       [0/3] 1 failed  testB (0.0sec)")

    // timer is per method and ticks while it runs
    r.fixedNow = 12300ms
    verifyEq(r.liveLine, "  FooTest       [0/3] 1 failed  testB (2.3sec)")
    r.fixedNow = 85sec
    verifyEq(r.liveLine, "  FooTest       [0/3] 1 failed  testB (1min 15sec)")
    r.onPass("acme::FooTest.testB", 1)
    r.onStart("acme::FooTest.testC")
    verifyEq(r.liveLine, "  FooTest       [1/3] 1 failed  testC (0.0sec)")

    // type done
    r.onPass("acme::FooTest.testC", 1)
    verifyEq(r.liveLine, null)

    // never shown in quiet mode
    q := Runner(["acme"], tests, true, false, Buf().out)
    q.onStart("acme::FooTest.testA")
    verifyEq(q.liveLine, null)
  }

  Void testLiveLineTruncate()
  {
    // width is 80 when not a tty; method is cut so line plus timer fits
    name := "test" + "x" * 70
    r := Runner(["acme"], ["acme::FooTest.$name"], false, false, Buf().out)
    r.fixedNow = 0ms
    r.onStart("acme::FooTest.$name")
    line := r.liveLine
    verifyEq(line.size, 79)
    verify(line.endsWith("x… (0.0sec)"))
  }

  Void testQuiet()
  {
    buf := Buf()
    r := Runner(["acme"], ["acme::FooTest.testA", "acme::FooTest.testB"], true, false, buf.out)
    r.onStart("acme::FooTest.testA")
    r.onPass("acme::FooTest.testA", 3)
    r.onStart("acme::FooTest.testB")
    r.onFail("acme::FooTest.testB", [,], ["sys::Err: boom"])
    verifyEq(buf.flip.readAllLines,
      ["FAIL: acme::FooTest.testB",
       "  sys::Err: boom",
       ""])
  }
}
