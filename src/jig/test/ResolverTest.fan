//
// Copyright (c) 2026, Novant LLC
// Licensed under the MIT License
//
// History:
//   26 Oct 2026  Andy Frank  Creation
//

*************************************************************************
** ResolverTest
*************************************************************************

class ResolverTest : Test
{
  Void testPod()
  {
    tests := Resolver.resolve(["jig"])
    verify(tests.contains("jig::ResolverTest.testPod"))
    verify(tests.contains("jig::MainTest.testWorkPods"))
    verifyEq(tests.findAll { !it.startsWith("jig::") }, Str[,])
    // abstract test types are skipped
    verifyEq(tests.findAll { it.startsWith("jig::AbstractFxTest.") }, Str[,])
  }

  Void testType()
  {
    verifyEq(Resolver.resolve(["jig::ResolverFxTest"]),
      ["jig::ResolverFxTest.testInherited", "jig::ResolverFxTest.testOne", "jig::ResolverFxTest.testTwo"])
  }

  Void testMethod()
  {
    verifyEq(Resolver.resolve(["jig::ResolverFxTest.testTwo"]), ["jig::ResolverFxTest.testTwo"])
    verifyEq(Resolver.resolve(["jig::ResolverFxTest.testTwo", "jig::ResolverFxTest.testOne"]),
      ["jig::ResolverFxTest.testTwo", "jig::ResolverFxTest.testOne"])
  }

  Void testErrs()
  {
    verifyErrMsg(ArgErr#, "Unknown pod: noSuchPod") { Resolver.resolve(["noSuchPod"]) }
    verifyErrMsg(ArgErr#, "Unknown type: jig::Nope") { Resolver.resolve(["jig::Nope"]) }
    verifyErrMsg(ArgErr#, "Not a Test type: jig::Main") { Resolver.resolve(["jig::Main"]) }
    verifyErrMsg(ArgErr#, "Unknown method: jig::ResolverFxTest.testNope") { Resolver.resolve(["jig::ResolverFxTest.testNope"]) }
  }
}

** Fixtures for ResolverTest (all trivially pass).
abstract class AbstractFxTest : Test
{
  Void testInherited() {}
}

class ResolverFxTest : AbstractFxTest
{
  Void testOne() {}
  Void testTwo() {}
  Void helper() {}
}
