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
}
