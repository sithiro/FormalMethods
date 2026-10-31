# FormalMethods

A C# console app whose core logic is written in [Dafny](https://dafny.org) and **proven correct** before it is compiled.

- `BinarySearch.dfy` — Dafny source. The method states what it guarantees (`requires` / `ensures`), and Dafny proves the code meets it.
- `Dafny.cs` — C# **generated** from all `.dfy` files on every build. Do not edit it; edit the `.dfy` files instead.
- `Program.cs` — ordinary C# that calls the verified methods.

## Why bother? The binary search bug

For years Java's `Arrays.binarySearch` computed its midpoint as `(low + high) / 2`. When `low + high`
exceeds the largest `int` (arrays of about a billion elements or more), the sum overflows to a negative
number and the search crashes. It passed every test, because no test used an array that large
([Joshua Bloch, 2006](https://research.google/blog/extra-extra-read-all-about-it-nearly-all-binary-searches-and-mergesorts-are-broken/)).

`BinarySearch.dfy` uses 32-bit integers like Java and C#. With the original midpoint, the build fails:

```
BinarySearch.dfy(30,27): error : result of operation might violate newtype constraint for 'int32'
Dafny program verifier finished with 6 verified, 1 error
Build FAILED.
```

The same line in plain C# compiles without a warning and silently returns a negative number;
`Program.cs` shows it.

With the fix, `low + (high - low) / 2`, it verifies. Three things a check inside the function could not do:

1. **Find a bug nobody thought of.** To write an overflow check you must already suspect the overflow,
   at which point you would just fix it. Dafny checks every operation for every possible input.
2. **Cover inputs tests never use.** A test proves one call works; the proof covers every array size
   and content, including the billion-element ones.
3. **Guarantee what is too costly to check at run time.** The contract says the input is sorted and
   that "not found" really means not found. Checking either at run time means scanning the whole
   array, which defeats the point of binary search. Dafny proves them once, at build time, for free.

To see it fail, follow the "TRY IT" comment under line 30 of `BinarySearch.dfy` and build.

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
Sorted:  2, 3, 7, 9, 12, 15
Search 7: found at index 2
Search 15: found at index 5
Search 5: not found

C# (low + high) / 2 with both = int.MaxValue: -1
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
