//
// Copyright (c) 2026, Novant LLC
// Licensed under the MIT License
//
// History:
//   26 Oct 2026  Andy Frank  Creation
//

*************************************************************************
** FantParserTest
*************************************************************************

class FantParserTest : Test
{
  Void testPassFail()
  {
    r := parse(
      """-- Run: acme::FooTest.testA
            Pass: acme::FooTest.testA [3]
         -- Run: acme::FooTest.testB
         some echo output

         TEST FAILED
         sys::TestErr: Test failed: 1 != 2
           acme::FooTest.testB (FooTest.fan:12)

         -- Run: acme::FooTest.testC
         Pass: not really
            Pass: acme::FooTest.testC [1]

         Time: 12ms

         Failed:
           acme::FooTest.testB

         ***
         *** 1 FAILURES [1 types, 3 methods, 5 verifies]
         ***
         """)

    verifyEq(r.events, [
      "start acme::FooTest.testA",
      "pass acme::FooTest.testA 3",
      "start acme::FooTest.testB",
      "fail acme::FooTest.testB [some echo output] [sys::TestErr: Test failed: 1 != 2,   acme::FooTest.testB (FooTest.fan:12)]",
      "start acme::FooTest.testC",
      "pass acme::FooTest.testC 1",
      "summary 1 3 5",
    ])
    verify(r.parser.isDone)
  }

  Void testFailLast()
  {
    // failure immediately followed by summary
    r := parse(
      """-- Run: acme::FooTest.testA

         TEST FAILED
         sys::Err: boom

         Time: 1ms

         ***
         *** 1 FAILURES [1 types, 1 methods, 0 verifies]
         ***""")
    verifyEq(r.events, [
      "start acme::FooTest.testA",
      "fail acme::FooTest.testA [,] [sys::Err: boom]",
      "summary 1 1 0",
    ])
  }

  Void testStray()
  {
    // fant crashes before running anything
    r := parse(
      """
         ERROR: sys::UnknownPodErr: nope
         """)
    verifyEq(r.events, ["stray ERROR: sys::UnknownPodErr: nope"])
    verifyFalse(r.parser.isDone)
  }

  Void testFinish()
  {
    // output ends mid-trace (process killed)
    r := parse(
      """-- Run: acme::FooTest.testA

         TEST FAILED
         sys::Err: boom""")
    verifyEq(r.events, ["start acme::FooTest.testA"])
    r.parser.finish
    verifyEq(r.events.last, "fail acme::FooTest.testA [,] [sys::Err: boom]")
    verifyFalse(r.parser.isDone)
  }

  Void testAllPassed()
  {
    r := parse(
      """-- Run: acme::FooTest.testA
            Pass: acme::FooTest.testA [0]

         Time: 1ms

         ***
         *** All tests passed! [1 types, 1 methods, 0 verifies]
         ***
         -- Run: ignored after done""")
    verifyEq(r.events.last, "summary 1 1 0")
    verifyEq(r.events.size, 3)
  }

  private FxListener parse(Str text)
  {
    r := FxListener()
    r.parser = FantParser(r)
    text.splitLines.each |line| { r.parser.parseLine(line) }
    return r
  }
}

internal class FxListener : FantListener
{
  FantParser? parser
  Str[] events := [,]
  override Void onStart(Str q) { events.add("start $q") }
  override Void onPass(Str q, Int v) { events.add("pass $q $v") }
  override Void onFail(Str q, Str[] o, Str[] t) { events.add("fail $q $o $t") }
  override Void onStray(Str s) { events.add("stray $s") }
  override Void onSummary(Int t, Int m, Int v) { events.add("summary $t $m $v") }
}
