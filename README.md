# Jig

A better Fantom test runner.

Jig wraps `fant` with output you can scan: results grouped by pod and test
class, a live status bar pinned to the bottom of the terminal, and failures
printed with only the output and stack frames that matter.

![jig running two pods: finished classes with pass counts and times, the class in progress with a live timer, and the status bar](assets/demo.svg)

## Usage

```
jig [options] <targets>*
```

Targets use the same syntax as `fant`:

```
fan jig acme                      // all tests in pod
fan jig acme::FooTest             // all tests in a type
fan jig acme::FooTest.testBar     // a single test method
fan jig -work                     // all pods in workDir lib/fan/
```

Options:

| Option                   | Description                                         |
|--------------------------|-----------------------------------------------------|
| `-work`                  | Test all pods in your workenv's `lib/fan/`          |
| `-quiet`, `-q`, `--quiet`| Only print failures, status bar, and summary        |
| `-es`                    | Test new ECMA JavaScript environment (passthrough)  |
| `-js`                    | Test legacy JavaScript environment (passthrough)    |

Exit code is `0` if all tests pass, `1` otherwise.

### `-work` vs `fant -all`

`fant -all` runs every pod the env can resolve, including Fantom core and
any `fan.props` path dependencies. `jig -work` only runs pods built into your
workenv's own `lib/fan/`, and refuses to run outside a workenv.

## Output

**Default** prints one line per test class, grouped by pod:

  - `[passed/total]` counts, aligned within each pod
  - `pass` / `fail` with elapsed time for the class (`4900ms` under 5sec,
    `12sec` under a minute, then `1min 2sec`)
  - Failures indented under their class: `FAIL: <method>`, anything the test
    printed (prefixed with `|`), and the stack trace with test harness frames
    (reflection, `TestRunner`, `verify` internals) removed

Output from passing tests is hidden.

**Quiet** (`-q`) prints failures as they happen with full qualified names,
and nothing for passing tests.

Both modes end with a one-line summary plus one line per failure showing how
many tests in that class failed.

**Status bar.** When stdout is a terminal, a status bar on the bottom line
shows progress, pass/fail counts, and total elapsed time. In default mode the
class currently running sits just above it with live counts and a timer for
the running method. Colors and the status bar are disabled when output is
piped, `CI` is set, or `TERM=dumb`.

## How it works

Jig resolves targets up front (so typos fail fast and the status bar knows
the total), spawns a single `fant` process, and parses its output as tests
run.
