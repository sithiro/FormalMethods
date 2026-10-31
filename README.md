# FormalMethods

A C# console app whose core logic is written in [Dafny](https://dafny.org) and **proven correct** before it is compiled.

- `*.dfy` — one Dafny file per example. Each states what it guarantees (`requires` / `ensures`), and Dafny proves the code meets it.
- `Dafny.cs` — C# **generated** from all `.dfy` files on every build. Do not edit it; edit the `.dfy` files instead.
- `Program.cs` — ordinary C# that calls each verified method, next to the original bug written in plain C#.

## The examples: real bugs that passed every test

Each example is a bug that shipped in real software. In each case the faulty code compiles in C# without
an error and works on ordinary inputs; it only fails on a rare input nobody tested. Dafny rejects
the faulty version at build time, without running it and without being told which input to try.

| # | Example         | Kind of bug                 | Dafny's check                             |
|---|-----------------|-----------------------------|-------------------------------------------|
| 1 | Binary search   | Integer overflow            | Arithmetic stays inside the declared type |
| 2 | Zune freeze     | Loop that never ends        | Every loop provably terminates            |
| 3 | Ariane 5        | Value too big for its type  | Conversions stay inside the target type   |
| 4 | Heartbleed      | Reading past an array's end | Every array index is inside the array     |
| 5 | Apple goto fail | Wrong result, no crash      | The result meets the `ensures` (the spec) |
| 6 | USS Yorktown    | Division by zero            | Every divisor is non-zero                 |

Each `.dfy` file contains the original faulty code in a commented-out **TRY IT** block, with
instructions and the exact error to expect. Enable it, run `dotnet build`, and watch the build fail.

### 1. Binary search: integer overflow (`BinarySearch.dfy`)

For years Java's `Arrays.binarySearch` computed its midpoint as `(low + high) / 2`. When `low + high`
exceeds the largest `int` (arrays of about a billion elements or more), the sum overflows to a negative
number and the search crashes. It passed every test, because no test used an array that large
([Joshua Bloch, 2006](https://research.google/blog/extra-extra-read-all-about-it-nearly-all-binary-searches-and-mergesorts-are-broken/)).

```
BinarySearch.dfy(30,27): error : result of operation might violate newtype constraint for 'int32'
```

Fix: `low + (high - low) / 2`. In plain C#, `(low + high) / 2` for 1,500,000,000 and 2,000,000,000
silently gives `-397,483,648`.

### 2. Zune freeze: a loop that never ends (`ZuneFreeze.dfy`)

On 31 December 2008 every Microsoft Zune 30GB froze at boot. Its clock driver turned "days since 1980"
into a year with a loop that, on the 366th day of a leap year, changed nothing and spun forever. It had
worked on every other day for years
([Microsoft developer blog](https://learn.microsoft.com/en-us/archive/blogs/asklar/hello-w0rld0)).

```
ZuneFreeze.dfy(52,2): error : cannot prove termination; try supplying a decreases clause for the loop
```

Dafny requires every loop to provably end. The fixed version states `decreases days` and Dafny proves
`days` shrinks on every pass. In plain C#, the original loop is still running after a million passes.

### 3. Ariane 5: an unsafe narrowing conversion (`Ariane5.dfy`)

On 4 June 1996 the first Ariane 5 rocket broke up about 40 seconds after launch. Software reused from
Ariane 4 converted a 64-bit value (the horizontal bias) to a 16-bit integer; on Ariane 5's faster
trajectory it no longer fit, the conversion failed, and both guidance computers shut down
([Inquiry Board report](https://www.dcs.gla.ac.uk/~johnson/teaching/safety/reports/ariane5.html)).

```
Ariane5.dfy(45,10): error : result of operation might violate newtype constraint for 'int16'
```

Fix: prove the value fits, here by clamping out-of-range values to the 16-bit limits. In plain C#,
`(short)40000` silently becomes `-25536`.

(The original value was a 64-bit floating-point number; the example uses a 64-bit integer, which
makes the same point more simply.)

### 4. Heartbleed: reading past the end of an array (`Heartbleed.dfy`)

In April 2014 a flaw in OpenSSL, used by a large share of the web's secure servers, was disclosed. A
TLS heartbeat request says how long its payload is, and the server echoes that many bytes back.
OpenSSL never compared the claimed length with the bytes actually sent, so a client could send `HAT`,
claim 65,535 bytes, and receive `HAT` plus whatever followed it in the server's memory: possibly
passwords, cookies or private keys
([The Register](https://www.theregister.com/2014/04/09/heartbleed_explained/)).

```
Heartbleed.dfy(55,26): error : index out of range
```

Dafny requires every `a[i]` to be provably inside the array. Fix: reject a request that claims more
than it sent. `Program.cs` models the server's memory as one buffer to show what C leaked; real C#
arrays are bounds-checked and would throw instead.

### 5. Apple goto fail: a wrong answer, no crash (`GotoFail.dfy`)

In February 2014 Apple patched iOS and OS X because a duplicated line, `goto fail;`, in the code that
checks a secure server's signature jumped straight to the end with the error code still 0 ("success").
The signature was never checked, so an attacker on the network could impersonate any secure server
([David A. Wheeler's analysis](https://dwheeler.com/essays/apple-goto-fail.html)).

```
GotoFail.dfy(69,2): error : a postcondition could not be proved on this return path
```

This is the only example that is not a crash: the code ran fine and gave the wrong answer. Dafny
catches it because the method's `ensures` states the security property, *success only if the
signature is valid*, and the duplicated line returns success without checking. Fix: remove the line.

(C# does warn about this one, CS0162 "unreachable code". `Program.cs` silences it with a `#pragma`
to keep the build clean. A warning is easy to miss; Dafny makes it an error tied to the property
that actually matters.)

### 6. USS Yorktown: division by zero (`Yorktown.dfy`)

On 21 September 1997 the US Navy's "Smart Ship" test cruiser was on manoeuvres off Virginia when a
crew member entered a zero into a database field. The software divided by it, the ship's network
crashed, and the Yorktown was dead in the water for about 2 hours 45 minutes
([Government Computer News](https://gcn.com/digital-government/1998/11/navy-calibration-flaw-crashed-yorktown-lan/291783/)).

```
Yorktown.dfy(34,19): error : possible division by zero
```

Dafny requires every divisor to be provably non-zero. Fix: report a zero count instead of dividing.

### Why a check inside the function would not have caught these

1. **You can't check for a bug you didn't think of.** To write an overflow or termination check you
   must already suspect the problem, at which point you would just fix it. Dafny checks every
   operation and every loop for every possible input, unprompted.
2. **Tests only cover the inputs you pick.** Each bug needed one rare input: a billion-element array,
   the last day of a leap year, a faster rocket, a lying length field, a forged signature, a zero in
   a form. The proof covers all of them.
3. **Some guarantees cost too much to check at run time.** BinarySearch's contract says the input is
   sorted and "not found" really means not found; checking either means scanning the whole array.
   Dafny proves them once, at build time, at no run-time cost.

## Prerequisites

Building needs three things. Only the first is needed to *run* the finished app; Dafny and Z3 are build-time tools.

| Tool                    | Version                  | What it does                                      |
|-------------------------|--------------------------|---------------------------------------------------|
| .NET SDK                | 9.0 or later             | Builds and runs the C# project                    |
| Dafny (a .NET tool)     | 4.11.0                   | Verifies the .dfy files and translates them to C# |
| Z3 (a separate program) | 4.12.1; 5.3.3 also works | Theorem prover Dafny uses to check proofs         |

Get the .NET SDK from https://dotnet.microsoft.com/download. Z3 4.12.1 is the version Dafny 4.11 is
officially tested with; 5.3.3 has been tested with this project.

The `DafnyRuntime` NuGet package is also needed, but it is referenced by the project and restored automatically by `dotnet build`.

### 1. Install Dafny

```
dotnet tool install -g dafny --version 4.11.0
```

This puts the `dafny` command in `%USERPROFILE%\.dotnet\tools`, which the .NET SDK adds to your PATH. Open a new terminal and check:

```
dafny --version
```

The Dafny version must match the `DafnyRuntime` package. Both come from one setting, `DafnyVersion` in
`FormalMethods.csproj` (currently 4.11.0); to move to another Dafny version, change it there and install
that version of the tool.

**The build checks all of this for you.** Before running Dafny it confirms that the `dafny` command
exists, that its version matches `DafnyVersion`, and that Z3 is present and runs. If anything is
missing it stops with a message saying exactly what to install (see Troubleshooting). The checks
are in the build rather than in `Program.cs` because the program cannot start until the build has
succeeded, and the finished program does not use Dafny or Z3 at all.

> The .NET tool does **not** include Z3, so the next step is required.

### 2. Install Z3

1. Go to the [Z3 releases page](https://github.com/Z3Prover/z3/releases) and download the zip for your platform, e.g. `z3-<version>-x64-win.zip`.
2. Extract it so that `z3.exe` ends up at:

   ```
   %USERPROFILE%\Documents\repos\z3\bin\z3.exe
   ```

   (That is, rename the extracted `z3-<version>-x64-win` folder to `z3` and place it in `Documents\repos`, next to this project's folder.)

3. Check it runs:

   ```
   "%USERPROFILE%\Documents\repos\z3\bin\z3.exe" --version
   ```

#### Z3 somewhere else?

If you keep Z3 in a different place, point the build at it in any of these ways:

- **Environment variable** (applies to every build, including Visual Studio — restart it afterwards):

  ```
  setx DafnySolverPath "C:\tools\z3\bin\z3.exe"
  ```

- **One build only:**

  ```
  dotnet build -p:DafnySolverPath="C:\tools\z3\bin\z3.exe"
  ```

- **Permanently for this project:** edit the default `DafnySolverPath` in `FormalMethods.csproj`.

Adding Z3's `bin` folder to your PATH is optional (handy for running `z3` yourself) but not enough on its own: Dafny 4.11 crashes if it picks up Z3 5.x from PATH, so the build always passes the path explicitly.

## Build and run

From this folder:

```
dotnet run
```

or open `FormalMethods.sln` in Visual Studio and press F5.

Expected output:

```
Dafny: search [2, 3, 7, 9, 12, 15] for 7 = index 2, for 5 = -1 (not found)
C#:    (low + high) / 2 for 1,500,000,000 and 2,000,000,000 = -397,483,648 (no warning, negative index)

Dafny: day 10593 since 1980 is day 366 of 2008
C#:    original loop still running after 1,000,000 passes (stuck at 2008, day 366)

Dafny: ConvertHorizontalBias(40,000) = 32,767 (clamped to the 16-bit limit)
C#:    (short)40,000 = -25,536 (no warning, wrong sign)

Dafny: heartbeat "HAT" claiming 30 bytes = "" (rejected: claimed more than it sent)
C#:    heartbeat "HAT" claiming 30 bytes = "HATuser=admin;password=hunter2" (leaked memory)

Dafny: verify forged signature = -9809 (rejected)
C#:    verify forged signature = 0 (accepted: signature never checked)

Dafny: average of 1,200 over 0 readings = not computed (zero count reported)
C#:    1,200 / 0 = DivideByZeroException (no compiler warning; the Yorktown's network crashed)
```

## How the build works

Before compiling, the build runs:

```
dafny translate cs <all .dfy files> --solver-path <Z3> --output Dafny
```

- **Verification first.** If any proof fails, the build fails with Dafny's error (file, line, and which `ensures`/`invariant` could not be proved). No C# is produced from unproven code.
- **All `.dfy` files go into one `Dafny.cs`.** Dafny emits shared helper code with every translation, so separately translated files would clash; translating them together avoids that.
- **Only when needed.** Dafny re-runs when a `.dfy` file is saved, added, or deleted, when `FormalMethods.csproj` changes, or when `Dafny.cs` is missing. Otherwise it is skipped. A **Rebuild** always regenerates.
- **New Dafny files** are picked up automatically: add a `.dfy` anywhere in the project folder and build. Top-level methods are called from C# as `_module.__default.MethodName(...)`.
- Dafny's `int` is unbounded, so it becomes `System.Numerics.BigInteger` in C#.

Calling a verified method from C# does not re-check its `requires`. For example, `BinarySearch` requires a sorted array; passing an unsorted one from C# gives wrong answers. Dafny proves it for Dafny callers only.

`.editorconfig` silences the harmless warnings Dafny's generated code triggers (e.g. CS0162), for `Dafny.cs` only. C# still warns when you pass `null` to a Dafny method.

## Troubleshooting

| Symptom                                                                       | Fix                                                                                         |
|-------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------|
| `Dafny is not installed (the 'dafny' command was not found)`                  | Install Dafny (step 1) and open a new terminal / restart Visual Studio.                     |
| `Dafny X is installed, but this project needs Dafny Y`                        | Install version Y (uninstall, then install with `--version Y`), or set `DafnyVersion` to X. |
| `Z3 not found at '...'`                                                       | Install Z3 (step 2) or set `DafnySolverPath`.                                               |
| `Z3 at '...' did not run`                                                     | The file is damaged or for another platform. Re-download the zip for your platform.         |
| `NullReferenceException ... SetZ3ExecutablePath` when running `dafny` by hand | Dafny couldn't use the Z3 it found on PATH. Pass `--solver-path <path to z3.exe>`.          |
| `Error: file ...\BinarySearch.dfy not found` when running `dafny` by hand     | Run it from this folder (`cd` here first).                                                  |
| Red squiggle under `_module` in the editor                                    | Build once so `Dafny.cs` exists, then reload the project.                                   |
| Proofs fail or hang unexpectedly with a newer Z3                              | Try Z3 4.12.1, the version Dafny 4.11 is tested against.                                    |
