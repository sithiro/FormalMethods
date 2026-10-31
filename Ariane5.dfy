// Ariane 5 flight 501, 4 June 1996.
//
// About 37 seconds after launch, the inertial reference software converted the horizontal bias (BH)
// from a 64-bit floating-point number to a 16-bit signed integer. On Ariane 5 the value was larger
// than a 16-bit integer can hold, the conversion raised an Operand Error, both inertial reference
// computers shut down, and the rocket veered off course and broke up. The code was reused from
// Ariane 4, where the value always fit. Other conversions had been protected; this one was not.
// See the Inquiry Board report: https://www.dcs.gla.ac.uk/~johnson/teaching/safety/reports/ariane5.html
//
// Here the input is a 64-bit integer (the original was a 64-bit float, which Dafny models
// differently). The point is the same: narrowing to 16 bits must be proven safe for every input.

newtype int16 = x: int | -0x8000 <= x < 0x8000
newtype int64 = x: int | -0x8000_0000_0000_0000 <= x < 0x8000_0000_0000_0000

// Converts to 16 bits, clamping out-of-range values to the nearest limit instead of failing.
method ConvertHorizontalBias(bh: int64) returns (r: int16)
  ensures -0x8000 <= bh as int < 0x8000 ==> r as int == bh as int   // in range: exact
  ensures bh as int >= 0x8000 ==> r == 0x7FFF                        // too big: 32767
  ensures bh as int < -0x8000 ==> r == -0x8000                       // too small: -32768
{
  if bh > 0x7FFF {
    r := 0x7FFF;
  } else if bh < -0x8000 {
    r := -0x8000;
  } else {
    r := bh as int16;
  }
}

// TRY IT: below is the unprotected conversion that flew on Ariane 5. Delete the line that holds
// only /* and the line that holds only */ (both are around the method), then run `dotnet build`.
//
// Expected: the build fails before anything runs, with
//
//     Ariane5.dfy(45,10): error : result of operation might violate newtype constraint for 'int16'
//     Build FAILED.
//
// Why: bh can be any 64-bit value, and most of them do not fit in 16 bits. Dafny will not let the
// conversion through until the code proves the value fits, either with a range check like the one
// above or with a `requires` that makes every caller prove it. Put the two lines back to make the
// build pass.
/*
method ConvertHorizontalBiasAriane(bh: int64) returns (r: int16)
{
  r := bh as int16;
}
*/
