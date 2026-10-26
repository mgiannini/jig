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
       "  FooTest ····· [1/2] fail (2500ms)",
       "    FAIL: testB",
       "      | echo",
       "      sys::Err: boom",
       "  LongNameTest  [1/1] pass (1min 2sec)",
       "  [✗ 1 failed, 2 passed (1min 4sec)]",
       "",
       "beta",
       "  BarTest ····· [1/1] pass (0ms)"])

    // last pod's summary is printed by run() once fant exits
    verifyEq(r.podSummary, ["  [✓ 1 passed (0ms)]"])
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

  Void testCountAlign()
  {
    // widest count in acme is 12/12; beta has its own column
    tests := Str[,]
    12.times |i| { tests.add("acme::BigTest.test$i") }
    tests.add("acme::SmallTest.testA")
    tests.add("beta::BarTest.testB")

    buf := Buf()
    r := Runner(["acme", "beta"], tests, false, false, buf.out)
    r.fixedNow = 0ms
    tests.each |q|
    {
      r.onStart(q)
      if (q == "acme::BigTest.test3") r.onFail(q, [,], ["sys::Err: boom"])
      else r.onPass(q, 1)
      if (q == "acme::SmallTest.testA") return
    }
    lines := buf.flip.readAllLines
    verifyEq(lines[1], "  BigTest ·· [11/12] fail (0ms)")
    verifyEq(lines.find { it.contains("SmallTest") }, "  SmallTest  [ 1/ 1] pass (0ms)")
    // columns are shared across pods
    verifyEq(lines.last, "  BarTest ·· [ 1/ 1] pass (0ms)")

    // passed padded independently of total
    r3 := Runner(["acme"], ["acme::T.testA"] .addAll((1..100).map { "acme::Big.test$it" }), false, false, Buf().out)
    r3.fixedNow = 0ms
    r3.onStart("acme::Big.test1")
    r3.onPass("acme::Big.test1", 1)
    r3.onStart("acme::Big.test2")
    verify(r3.liveLine.contains("[  1/100]"))

    // live line uses the same padding
    r2 := Runner(["acme"], tests, false, false, Buf().out)
    r2.fixedNow = 0ms
    r2.onStart("acme::SmallTest.testA")
    verifyEq(r2.liveLine, "  SmallTest  [ 0/ 1]  testA (0.0sec)")
  }

  Void testSummary()
  {
    tests := ["acme::FooTest.testA", "acme::FooTest.testB", "acme::FooTest.testC",
              "acme::LongNameTest.testD"]
    buf := Buf()
    r := Runner(["acme"], tests, true, false, buf.out)
    r.fixedNow = 0ms
    r.onStart(tests[0]); r.onFail(tests[0], [,], ["sys::Err: a"])
    r.onStart(tests[1]); r.onPass(tests[1], 1)
    r.onStart(tests[2]); r.onFail(tests[2], [,], ["sys::Err: c"])
    r.onStart(tests[3]); r.onFail(tests[3], [,], ["sys::Err: d"])
    r.onSummary(2, 4, 1234)
    buf.clear

    verifyEq(r.summary(3, true), 1)
    verifyEq(buf.flip.readAllLines,
      ["✗ 3 failed, 1 passed of 4 tests [1,234 verifies] in 0.0sec",
       "✗ acme::FooTest.testA      [2/3 failed]",
       "✗ acme::FooTest.testC      [2/3 failed]",
       "✗ acme::LongNameTest.testD [1/1 failed]"])
  }

  Void testSummaryPass()
  {
    buf := Buf()
    r := Runner(["acme"], ["acme::FooTest.testA"], true, false, buf.out)
    r.fixedNow = 0ms
    r.onStart("acme::FooTest.testA"); r.onPass("acme::FooTest.testA", 1)
    r.onSummary(1, 1, 1)
    verifyEq(r.summary(0, true), 0)
    verifyEq(buf.flip.readAllLines, ["✓ 1 test passed [1 verifies] in 0.0sec"])
  }

  Void testPodSummarySinglePod()
  {
    // final summary already covers a single pod
    buf := Buf()
    r := Runner(["acme"], ["acme::FooTest.testA"], false, false, buf.out)
    r.fixedNow = 0ms
    r.onStart("acme::FooTest.testA")
    r.onPass("acme::FooTest.testA", 1)
    verifyEq(r.podSummary, Str[,])
  }

  Void testBarLabel()
  {
    tests := ["acme::FooTest.testA", "acme::FooTest.testB", "acme::BarTest.testC",
              "beta::BazTest.testD"]
    r := Runner(["acme", "beta"], tests, false, false, Buf().out)
    r.fixedNow = 0ms
    verifyEq(r.barLabel, null)

    // pod and its test progress, across classes
    r.onStart(tests[0])
    verifyEq(r.barLabel, "acme [0/3]")
    r.onPass(tests[0], 1)
    r.onStart(tests[1])
    r.onFail(tests[1], [,], ["sys::Err: boom"])
    r.onStart(tests[2])
    verifyEq(r.barLabel, "acme [2/3]")
    r.onPass(tests[2], 1)
    r.onStart(tests[3])
    verifyEq(r.barLabel, "beta [0/1]")

    // quiet mode shows the current test
    q := Runner(["acme"], tests, true, false, Buf().out)
    q.onStart(tests[1])
    verifyEq(q.barLabel, "acme::FooTest.testB")
  }

  Void testLiveLine()
  {
    tests := ["acme::FooTest.testA", "acme::FooTest.testB", "acme::FooTest.testC",
              "acme::LongNameTest.testD"]
    r := Runner(["acme"], tests, false, false, Buf().out)
    r.fixedNow = 0ms
    verifyEq(r.liveLine, null)

    r.onStart("acme::FooTest.testA")
    verifyEq(r.liveLine, "  FooTest ····· [0/3]  testA (0.0sec)")
    r.onFail("acme::FooTest.testA", [,], ["sys::Err: boom"])
    r.fixedNow = 10sec
    r.onStart("acme::FooTest.testB")
    verifyEq(r.liveLine, "  FooTest ····· [0/3] 1 failed  testB (0.0sec)")

    // timer is per method and ticks while it runs
    r.fixedNow = 12300ms
    verifyEq(r.liveLine, "  FooTest ····· [0/3] 1 failed  testB (2.3sec)")
    r.fixedNow = 85sec
    verifyEq(r.liveLine, "  FooTest ····· [0/3] 1 failed  testB (1min 15sec)")
    r.onPass("acme::FooTest.testB", 1)
    r.onStart("acme::FooTest.testC")
    verifyEq(r.liveLine, "  FooTest ····· [1/3] 1 failed  testC (0.0sec)")

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
