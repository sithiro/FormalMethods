# FormalMethods

A C# console app whose core logic is written in [Dafny](https://dafny.org) and **proven correct** before it is compiled.

- `*.dfy` — one Dafny file per example. Each states what it guarantees (`requires` / `ensures`), and Dafny proves the code meets it.
- `Dafny.cs` — C# **generated** from all `.dfy` files on every build. Do not edit it; edit the `.dfy` files instead.
- `Program.cs` — ordinary C# that calls each verified method, next to the original bug written in plain C#.

## The examples: real bugs that passed every test

Each example is a bug that shipped in real software. In each case the faulty code compiles in C# without
an error and works on ordinary inputs; it only fails on a rare input nobody tested. Dafny rejects
the faulty version at build time, without running it and without being told which input to try.

| #  | Example              | Kind of bug                                   | Dafny's check                                                     |
|----|----------------------|-----------------------------------------------|-------------------------------------------------------------------|
| 1  | Binary search        | Integer overflow                              | Arithmetic stays inside the declared type                         |
| 2  | Zune freeze          | Loop that never ends                          | Every loop provably terminates                                    |
| 3  | Ariane 5             | Value too big for its type                    | Conversions stay inside the target type                           |
| 4  | Heartbleed           | Reading past an array's end                   | Every array index is inside the array                             |
| 5  | Apple goto fail      | Wrong result, no crash                        | The result meets the `ensures` (the spec)                         |
| 6  | USS Yorktown         | Division by zero                              | Every divisor is non-zero                                         |
| 7  | Therac-25            | Overflow that disables a safety check         | Arithmetic stays in range, and the safety rule in `ensures` holds |
| 8  | Mars Climate Orbiter | Mixed-up units                                | Each unit is its own type (a type error, not a proof)             |
| 9  | Patriot missile      | Rounding error that grows over time           | The error bound in `ensures` holds for every uptime               |
| 10 | The DAO              | State updated in the wrong order across calls | A rule about the object's state holds whenever outside code runs  |

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

### 7. Therac-25: an overflow that switched off a safety check (`Therac25.dfy`)

Between 1985 and 1987 the Therac-25 radiation therapy machine gave several patients massive
overdoses; some died. It relied on software alone for safety. One guard was a one-byte flag: non-zero
meant "check the collimator before firing", zero meant "all clear". The set-up code *incremented* the
flag instead of setting it, so every 256th pass it wrapped from 255 to 0 and the check was skipped
([Leveson and Turner, IEEE Computer, 1993](https://cs.huji.ac.il/w~feit/sem/se11/therac.pdf)).

```
Therac25.dfy(40,22): error : result of operation might violate newtype constraint for 'byte8'
```

Fix: set the flag to 1 instead of counting. This one is caught twice: the increment can overflow, and
if the wrap is written out on purpose (`% 256`), the safety rule `ensures newClass3 != 0` fails
instead. In plain C#, `byte` incremented 256 times is silently 0.

### 8. Mars Climate Orbiter: mixed-up units (`MarsClimateOrbiter.dfy`)

On 23 September 1999 NASA lost the Mars Climate Orbiter on arrival at Mars. Ground software produced
thruster impulses in pound-force seconds; the navigation software expected newton-seconds, as the
interface specification said. Every firing's effect was underestimated by a factor of 4.45
([review of the failure reports](https://arxiv.org/pdf/1903.02461)).

```
MarsClimateOrbiter.dfy(58,37): error : incorrect argument type for method in-parameter 'impulse' (expected NewtonSeconds, found PoundForceSeconds)
```

Each unit is its own `newtype`, so passing one where the other is expected does not compile; the fix
is an explicit conversion. This is the one example that is a type check rather than a proof. C# could
do the same with a separate struct per unit, but plain numbers are the norm. Note that the distinction
exists only inside Dafny: in the generated C# both units are `BigInteger`.

### 9. Patriot missile: a rounding error that grew with uptime (`Patriot.dfy`)

On 25 February 1991 a Patriot battery at Dhahran, Saudi Arabia, failed to track an incoming Scud,
which hit an Army barracks and killed 28 Americans. The Patriot counted time in tenths of a second and
multiplied by 0.1 in 24-bit arithmetic; 0.1 has no exact binary form, so each tick lost about
0.000000095 s. The battery had been running for over 100 hours, by which point its clock was about
0.34 s behind, enough for the radar to look in the wrong place
([GAO report IMTEC-92-26](https://www.gao.gov/products/IMTEC-92-26)).

```
Patriot.dfy(49): error : a postcondition could not be proved on this return path
```

The `ensures` says the clock never lags true time by more than 10 ms. Dafny's real numbers are exact,
so it can tell the original breaks that promise. The TRY IT block goes further: add
`requires ticks <= 104857` and the original verifies; make it 104858 and it fails. Dafny pins down the
exact assumption the code silently relied on, about 2.9 hours of uptime. Fix: divide by 10 exactly.

### 10. The DAO: state updated in the wrong order (`TheDao.dfy`)

In June 2016 an attacker drained about 3.6 million ether from The DAO, an investment fund running on
Ethereum. Its withdraw function sent the investor's ether first and cleared their balance last.
Sending ether to a contract runs that contract's code, so the attacker's contract called withdraw
again before its balance was cleared, and was paid again, repeatedly. Ethereum reversed the theft with
a hard fork ([WithSecure Labs analysis](https://labs.withsecure.com/publications/the-hack-that-changed-the-blockchain-perspective)).

```
TheDao.dfy(68,34): error : a precondition for this call could not be proved
```

Every other example is a bug inside one calculation; this one is about the *order* of changes to an
object's state across calls. The class states a rule, *the fund holds at least what it owes*, that
every call must respect, including the call back in from the recipient. In the original order the
ether has already left but the balance still says it is owed, so Dafny rejects the call back in.
Fix: record the withdrawal first, then send.

### Why a check inside the function would not have caught these

1. **You can't check for a bug you didn't think of.** To write an overflow or termination check you
   must already suspect the problem, at which point you would just fix it. Dafny checks every
   operation and every loop for every possible input, unprompted.
2. **Tests only cover the inputs you pick.** Each bug needed one rare input: a billion-element array,
   the last day of a leap year, a faster rocket, a lying length field, a forged signature, a zero in
   a form, the 256th pass through a loop, 100 hours of uptime, a contract that calls back in. The
   proof covers all of them.
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
1. Binary search (Java, 2006): integer overflow in the midpoint
---------------------------------------------------------------
Dafny: search [2, 3, 7, 9, 12, 15] for 7 = index 2, for 5 = -1 (not found)
C#:    (low + high) / 2 for 1,500,000,000 and 2,000,000,000 = -397,483,648 (no warning, negative index)

2. Zune freeze (Microsoft, 2008): a loop that never ends
--------------------------------------------------------
Dafny: day 10593 since 1980 is day 366 of 2008
C#:    original loop still running after 1,000,000 passes (stuck at 2008, day 366)

3. Ariane 5 (ESA, 1996): a 64-bit value converted to 16 bits
------------------------------------------------------------
Dafny: ConvertHorizontalBias(40,000) = 32,767 (clamped to the 16-bit limit)
C#:    (short)40,000 = -25,536 (no warning, wrong sign)

4. Heartbleed (OpenSSL, 2014): reading past the end of the payload
------------------------------------------------------------------
Dafny: heartbeat "HAT" claiming 30 bytes = "" (rejected: claimed more than it sent)
C#:    heartbeat "HAT" claiming 30 bytes = "HATuser=admin;password=hunter2" (leaked memory)

5. Apple goto fail (iOS and OS X, 2014): signature never checked, no crash
--------------------------------------------------------------------------
Dafny: verify forged signature = -9809 (rejected)
C#:    verify forged signature = 0 (accepted: signature never checked)

6. USS Yorktown (US Navy, 1997): division by zero
-------------------------------------------------
Dafny: average of 1,200 over 0 readings = not computed (zero count reported)
C#:    1,200 / 0 = DivideByZeroException (no compiler warning; the Yorktown's network crashed)

7. Therac-25 (1985-87): a wrapped counter switched off a safety check
---------------------------------------------------------------------
Dafny: Class3 flag after 256 set-up passes = 1 (collimator check still required)
C#:    Class3 flag after 256 set-up passes = 0 (wrapped to 0: collimator check skipped)

8. Mars Climate Orbiter (NASA, 1999): pound-force seconds used as newton-seconds
--------------------------------------------------------------------------------
Dafny: 100 lbf·s converted to 444 N·s, trajectory correction 222
C#:    100 lbf·s used as 100 N·s, trajectory correction 50 (about 4.45x too small: the orbiter was lost)

9. Patriot missile (US Army, 1991): a rounding error that grew with uptime
--------------------------------------------------------------------------
Dafny: clock after 100 hours = 360,000.0000 s (exact)
C#:    clock after 100 hours = 359,999.6567 s (0.3433 s behind: the radar looked in the wrong place)

10. The DAO (Ethereum, 2016): paid out before updating the balance
------------------------------------------------------------------
Dafny: investor owed 10 withdraws, calling back in 5 times: paid 10, fund holds 90
C#:    investor owed 10 withdraws, calling back in 5 times: paid 60, fund holds 40 (drained)
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
