// USS Yorktown, 21 September 1997.
//
// The Yorktown was the US Navy's "Smart Ship" test bed, running its systems on networked computers.
// During manoeuvres off Virginia a crew member entered a zero into a database field. The software
// divided by it, the error crashed the computers on the ship's network, and the cruiser lost
// propulsion: it was dead in the water for about 2 hours 45 minutes.
// See https://gcn.com/digital-government/1998/11/navy-calibration-flaw-crashed-yorktown-lan/291783/
//
// Dafny requires every division to have a provably non-zero divisor. It rejects the original.

// Averages a total over a count of readings. A zero count is reported instead of crashing.
method AverageReading(total: int, count: int) returns (ok: bool, average: int)
  ensures ok <==> count != 0
  ensures ok ==> average == total / count
{
  if count == 0 {
    return false, 0;
  }
  return true, total / count;
}

// TRY IT: below is the unguarded division. Delete the line that holds only /* and the line that
// holds only */ (both are around the method), then run `dotnet build`.
//
// Expected: the build fails before anything runs, with
//
//     Yorktown.dfy(34,19): error : possible division by zero
//     Build FAILED.
//
// Why: count comes from outside (on the Yorktown, from a database field a person typed into), and
// nothing proves it is not zero. Put the two lines back to make the build pass.
/*
method AverageReadingYorktown(total: int, count: int) returns (average: int)
{
  average := total / count;
}
*/
