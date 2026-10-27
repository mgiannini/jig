#! /usr/bin/env fan

using build

class Build : BuildPod
{
  new make()
  {
    podName = "jig"
    summary = "A better Fantom build and test tool"
    version = Version("0.2")
    meta = [
      "org.name":     "Novant",
      "org.uri":      "https://novant.io/",
      "license.name": "MIT",
      "vcs.name":     "Git",
      "vcs.uri":      "https://github.com/novant-io/jig",
      "repo.public":  "true",
      "repo.tags":    "test,build",
    ]
    depends = [
      "sys 1.0",
      "util 1.0",
      "concurrent 1.0",
      "build 1.0",
    ]
    srcDirs = [
      `fan/`,
      `test/`,
    ]
    resDirs = [`doc/`]
    docApi = true
    docSrc = true
  }
}
