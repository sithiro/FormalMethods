# FormalMethods

A C# console app whose core logic is written in [Dafny](https://dafny.org) and **proven correct** before it is compiled.

- `Max.dfy`, `Min.dfy` — Dafny source. Each method states what it guarantees (`requires` / `ensures`), and Dafny proves the code meets it.
- `Dafny.cs` — C# **generated** from all `.dfy` files on every build. Do not edit it; edit the `.dfy` files instead.
- `Program.cs` — ordinary C# that calls the verified methods.

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
Numbers: 3, 9, 2, 7
Max:     9
Min:     2
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

Calling a verified method from C# does not re-check its `requires`. For example, `Max` and `Min` require a non-empty array; passing an empty one from C# will throw at runtime.

## Troubleshooting

| Symptom                                                                       | Fix                                                                                |
|-------------------------------------------------------------------------------|------------------------------------------------------------------------------------|
| `'dafny' is not recognized`                                                   | Install Dafny (step 1) and open a new terminal / restart Visual Studio.            |
| `Z3 not found at '...'`                                                       | Install Z3 (step 2) or set `DafnySolverPath`.                                      |
| `NullReferenceException ... SetZ3ExecutablePath` when running `dafny` by hand | Dafny couldn't use the Z3 it found on PATH. Pass `--solver-path <path to z3.exe>`. |
| `Error: file ...\Max.dfy not found` when running `dafny` by hand              | Run it from this folder (`cd` here first).                                         |
| Red squiggle under `_module` in the editor                                    | Build once so `Dafny.cs` exists, then reload the project.                          |
| Proofs fail or hang unexpectedly with a newer Z3                              | Try Z3 4.12.1, the version Dafny 4.11 is tested against.                           |
