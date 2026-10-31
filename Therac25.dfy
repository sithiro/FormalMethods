// Therac-25 radiation therapy machine, 1985-1987.
//
// Software alone guarded the beam: earlier models had hardware interlocks, the Therac-25 did not.
// One guard was a one-byte flag, Class3. Non-zero meant "check the collimator position before
// firing"; zero meant "all clear". The set-up routine did not set the flag, it incremented it, once
// per pass. A byte holds 0 to 255, so every 256th pass the flag wrapped from 255 to 0, the
// collimator check was skipped, and an operator pressing "set" at that moment could fire the beam
// with the machine wrongly configured. Patients received massive overdoses; several died.
// See Leveson and Turner, "An Investigation of the Therac-25 Accidents", IEEE Computer, 1993:
// https://cs.huji.ac.il/w~feit/sem/se11/therac.pdf
//
// Dafny rejects the increment because it can overflow the byte. And if the wrap is written out on
// purpose, the `ensures` below (the safety rule) still rejects it.

newtype byte8 = x: int | 0 <= x < 0x100

// One pass of the set-up test. Returns the new Class3 flag.
method SetUpTestPass(class3: byte8) returns (newClass3: byte8)
  ensures newClass3 != 0        // the safety rule: "check the collimator" must never read as "all clear"
{
  newClass3 := 1;               // the fix: set the flag to a fixed non-zero value, don't count
}

// TRY IT: below is the original: increment the flag on every pass. Delete the line that holds only
// /* and the line that holds only */ (both are around the method), then run `dotnet build`.
//
// Expected: the build fails before anything runs, with
//
//     Therac25.dfy(40,22): error : result of operation might violate newtype constraint for 'byte8'
//     Build FAILED.
//
// Why: class3 can be 255, and 255 + 1 does not fit in a byte. In the real machine (and in C#) it
// silently became 0. If you write that wrap out on purpose,
//     newClass3 := ((class3 as int + 1) % 256) as byte8;
// Dafny instead reports "a postcondition could not be proved", because the result can be 0 and the
// safety rule says it never may. Either way the build fails. Put the two lines back to make it pass.
/*
method SetUpTestPassTherac(class3: byte8) returns (newClass3: byte8)
  ensures newClass3 != 0
{
  newClass3 := class3 + 1;
}
*/
