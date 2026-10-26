//
// Copyright (c) 2026, Novant LLC
// Licensed under the MIT License
//
// History:
//   26 Oct 2026  Andy Frank  Creation
//

*************************************************************************
** Resolver
*************************************************************************

** Resolver expands command line targets into the qualified test
** method names fant will run, using the same rules as 'TestRunner'.
const class Resolver
{
  ** Resolve targets to test method qnames, or throw ArgErr if
  ** any target does not exist.
  static Str[] resolve(Str[] targets)
  {
    acc := Str[,]
    targets.each |t| { acc.addAll(resolveTarget(t)) }
    return acc
  }

  ** Resolve a single '<pod>', '<pod>::<Type>', or '<pod>::<Type>.<method>'.
  static Str[] resolveTarget(Str target)
  {
    // pod
    colons := target.index("::")
    if (colons == null) return podTests(findPod(target))

    // pod::Type
    pod  := findPod(target[0..<colons])
    rest := target[colons+2..-1]
    dot  := rest.index(".")
    if (dot == null) return typeTests(findType(pod, rest))

    // pod::Type.method
    type := findType(pod, rest[0..<dot])
    name := rest[dot+1..-1]
    if (type.method(name, false) == null) throw ArgErr("Unknown method: ${type.qname}.${name}")
    return ["${type.qname}.${name}"]
  }

  ** All test methods on all concrete Test types in pod.
  static Str[] podTests(Pod pod)
  {
    acc := Str[,]
    pod.types.each |t|
    {
      if (t.fits(Test#) && !t.isAbstract) acc.addAll(typeTests(t))
    }
    return acc
  }

  ** All 'test*' methods on given type.
  static Str[] typeTests(Type type)
  {
    type.methods
      .findAll |m| { m.name.startsWith("test") && !m.isAbstract }
      .map |m->Str| { "${type.qname}.${m.name}" }
  }

  private static Pod findPod(Str name)
  {
    Pod.find(name, false) ?: throw ArgErr("Unknown pod: $name")
  }

  private static Type findType(Pod pod, Str name)
  {
    type := pod.type(name, false) ?: throw ArgErr("Unknown type: ${pod.name}::${name}")
    if (!type.fits(Test#)) throw ArgErr("Not a Test type: $type.qname")
    return type
  }
}
