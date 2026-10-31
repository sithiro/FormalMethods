# FormalMethods

A C# console app whose core logic is written in [Dafny](https://dafny.org) and **proven correct** before it is compiled.

- `*.dfy` — one Dafny file per example. Each states what it guarantees (`requires` / `ensures`), and Dafny proves the code meets it.
- `Dafny.cs` — C# **generated** from all `.dfy` files on every build. Do not edit it; edit the `.dfy` files instead.
- `Program.cs` — ordinary C# that calls each verified method, next to the original bug written in plain C#.

## The examples: real bugs that passed every test

Each example is a bug that shipped in real software. In each case the faulty code compiles in C# without
a warning and works on ordinary inputs; it only fails on a rare input nobody tested. Dafny rejects
the faulty version at build time, without running it and without being told which input to try.

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

### Why a check inside the function would not have caught these

1. **You can't check for a bug you didn't think of.** To write an overflow or termination check you
   must already suspect the problem, at which point you would just fix it. Dafny checks every
   operation and every loop for every possible input, unprompted.
2. **Tests only cover the inputs you pick.** Each bug needed one rare input: a billion-element array,
   the last day of a leap year, a faster rocket. The proof covers all of them.
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

The Dafny version must match the `DafnyRuntime` version in `FormalMethods.csproj` (both 4.11.0). If you upgrade one, upgrade the other.

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

| Symptom                                                                       | Fix                                                                                |
|-------------------------------------------------------------------------------|------------------------------------------------------------------------------------|
| `'dafny' is not recognized`                                                   | Install Dafny (step 1) and open a new terminal / restart Visual Studio.            |
| `Z3 not found at '...'`                                                       | Install Z3 (step 2) or set `DafnySolverPath`.                                      |
| `NullReferenceException ... SetZ3ExecutablePath` when running `dafny` by hand | Dafny couldn't use the Z3 it found on PATH. Pass `--solver-path <path to z3.exe>`. |
| `Error: file ...\BinarySearch.dfy not found` when running `dafny` by hand     | Run it from this folder (`cd` here first).                                         |
| Red squiggle under `_module` in the editor                                    | Build once so `Dafny.cs` exists, then reload the project.                          |
| Proofs fail or hang unexpectedly with a newer Z3                              | Try Z3 4.12.1, the version Dafny 4.11 is tested against.                           |
