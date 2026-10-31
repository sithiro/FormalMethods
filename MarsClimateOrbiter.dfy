// Mars Climate Orbiter, lost 23 September 1999.
//
// Ground software called "Small Forces" calculated the impulse from the spacecraft's thruster
// firings and handed it to the navigation software. The interface specification said newton-seconds;
// Small Forces produced pound-force seconds. One pound-force is about 4.45 newtons, so navigation
// underestimated every firing's effect by a factor of 4.45, the trajectory drifted, and the orbiter
// was lost on arrival at Mars. Both programs were correct on their own; the bug was at the hand-off,
// where a bare number carried no unit.
// See https://arxiv.org/pdf/1903.02461 (review of the Mars mission failure reports)
//
// In Dafny each unit can be its own type. Values of different newtypes cannot be mixed without an
// explicit conversion, so passing pound-force seconds where newton-seconds are expected does not
// even compile. Unlike the other examples, this is a type error, not a failed proof.

newtype NewtonSeconds = int
newtype PoundForceSeconds = int

// 1 lbf·s = 4.448222 N·s (rounded down to whole N·s).
function ToNewtonSeconds(impulse: PoundForceSeconds): NewtonSeconds {
  (impulse as int * 4448222 / 1000000) as NewtonSeconds
}

// Stands in for Small Forces: the impulse from a number of thruster firings, in pound-force seconds.
method SmallForces(firings: int) returns (impulse: PoundForceSeconds)
  requires firings >= 0
{
  impulse := (firings * 10) as PoundForceSeconds;
}

// Stands in for navigation: the trajectory correction for an impulse, which must be in newton-seconds.
method TrajectoryCorrection(impulse: NewtonSeconds) returns (correction: int) {
  correction := impulse as int / 2;
}

method Navigate(firings: int) returns (correction: int)
  requires firings >= 0
{
  var impulse := SmallForces(firings);
  correction := TrajectoryCorrection(ToNewtonSeconds(impulse));   // the conversion the hand-off needed
}

// TRY IT: below is the original hand-off: the pound-force value goes straight to navigation. Delete
// the line that holds only /* and the line that holds only */ (both are around the method), then
// run `dotnet build`.
//
// Expected: the build fails before anything runs, with
//
//     MarsClimateOrbiter.dfy(58,37): error : incorrect argument type for method in-parameter 'impulse' (expected NewtonSeconds, found PoundForceSeconds)
//     Build FAILED.
//
// Why: impulse is a PoundForceSeconds and TrajectoryCorrection takes NewtonSeconds. They are both
// whole numbers underneath, but Dafny treats them as different types. Put the two lines back to
// make the build pass.
/*
method NavigateMco(firings: int) returns (correction: int)
  requires firings >= 0
{
  var impulse := SmallForces(firings);
  correction := TrajectoryCorrection(impulse);
}
*/
