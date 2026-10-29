# Changelog

## Version 0.4 (working)

## Version 0.3 (29-Oct-2026)
* `jig build <pod>` works from anywhere in a repo: if the pod isn't under the root build script, find it by its directory under the repo's `src/`

## Version 0.2 (27-Oct-2026)
* **Breaking:** a command is now required; `jig acme` is `jig test acme`
* **Breaking:** drop `-w`; `jig test` with no targets tests the workenv
* Unknown options are now an error instead of a warning
* Add `jig build` to compile with the same output and status bar as tests
* Add `jig build -c` to clean only
* Add `jig build -f` to clean, compile, then test
* Add `jig build -t <target>` to run any build script target
* Show `TEST` or `BUILD` before the status bar progress

## Version 0.1 (26-Oct-2026)
* Initial MVP