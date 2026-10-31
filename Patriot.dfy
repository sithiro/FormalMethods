// Patriot missile battery, Dhahran, Saudi Arabia, 25 February 1991.
//
// The Patriot counted time in tenths of a second and converted it to seconds by multiplying by 0.1
// in 24-bit arithmetic. 0.1 has no exact binary form, so the stored value was slightly too small:
// 0.099999904632568359375, short by about 0.000000095 s per tick. The error grows with uptime. The
// battery at Dhahran had been running for over 100 hours, by which point its clock was off by about
// 0.34 s, enough for its radar to look in the wrong place. It failed to track an incoming Scud, which
// hit an Army barracks and killed 28 Americans. A software fix reached Dhahran the next day.
// See the GAO report: https://www.gao.gov/products/IMTEC-92-26
//
// Nothing here overflows or crashes; tiny rounding errors add up over time. Dafny's real numbers are
// exact, so it can prove (or refute) how far the computed clock may drift from the true one.

// 0.1 as the Patriot stored it, chopped to fit its 24-bit register.
const Tenth24Bit: real := 0.099999904632568359375

// How far the computed clock may lag behind true time: 10 ms.
const MaxClockError: real := 0.01

function TrueSeconds(ticks: nat): real {
  ticks as real / 10.0
}

// Converts uptime in tenths of a second to seconds, never lagging true time by more than 10 ms.
method UptimeSeconds(ticks: nat) returns (seconds: real)
  ensures TrueSeconds(ticks) - MaxClockError <= seconds <= TrueSeconds(ticks)
{
  seconds := ticks as real / 10.0;     // the fix: divide by 10 exactly, no stored approximation of 0.1
}

// TRY IT: below is the original: multiply by the 24-bit approximation of 0.1. Delete the line that
// holds only /* and the line that holds only */ (both are around the method), then run `dotnet build`.
//
// Expected: the build fails before anything runs, with
//
//     Patriot.dfy(49): error : a postcondition could not be proved on this return path
//     Build FAILED.
//
// Why: the lag is ticks * 0.000000095..., which passes 10 ms once ticks is large enough. Now add this
// line under the method's first line, to limit uptime:
//
//     requires ticks <= 104857
//
// and the build passes; change it to 104858 and it fails again. Dafny has found the exact assumption
// the original silently depended on: about 2.9 hours of uptime (104,857 tenths of a second). The
// battery at Dhahran had been up for over 100 hours. Put the two comment lines back when done.
/*
method UptimeSecondsPatriot(ticks: nat) returns (seconds: real)
  ensures TrueSeconds(ticks) - MaxClockError <= seconds <= TrueSeconds(ticks)
{
  seconds := ticks as real * Tenth24Bit;
}
*/
