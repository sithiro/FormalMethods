// The Microsoft Zune 30GB freeze, 31 December 2008.
//
// At boot the Zune converted "days since 1 Jan 1980" into a year. On the 366th day of a leap year
// (31 Dec 2008) the original loop below never changed `days` or `year`, so it spun forever and every
// 30GB Zune froze until 1 January 2009. The code ran for years without a problem before that day.
// See https://learn.microsoft.com/en-us/archive/blogs/asklar/hello-w0rld0
//
// Dafny requires every loop to provably end. It rejects the original loop at build time.

predicate IsLeapYear(y: int) {
  y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)
}

function DaysInYear(y: int): int {
  if IsLeapYear(y) then 366 else 365
}

// daysSince1980 = 1 is 1 January 1980. Returns the year and the day within that year (1-based).
method DaysToYear(daysSince1980: int) returns (year: int, dayOfYear: int)
  requires daysSince1980 >= 1
  ensures 1 <= dayOfYear <= DaysInYear(year)
{
  var days := daysSince1980;
  year := 1980;
  while days > DaysInYear(year)
    invariant days >= 1
    decreases days        // the proof that the loop ends: days gets smaller on every pass
  {
    days := days - DaysInYear(year);
    year := year + 1;
  }
  dayOfYear := days;
}

// TRY IT: below is the original Zune loop, translated line for line. Delete the line that holds
// only /* and the line that holds only */ (both are around the method), then run `dotnet build`.
//
// Expected: the build fails before anything runs, with
//
//     ZuneFreeze.dfy(52,2): error : cannot prove termination; try supplying a decreases clause for the loop
//     Build FAILED.
//
// Why: when IsLeapYear(year) is true and days == 366, neither branch changes anything, so the next
// pass is identical to this one, forever. Dafny cannot find anything that shrinks on every pass, so
// it refuses the loop. Adding `decreases days` does not help: Dafny then reports that days might not
// decrease, for the same case. Put the two lines back to make the build pass.
/*
method DaysToYearZune(daysSince1980: int) returns (year: int, dayOfYear: int)
  requires daysSince1980 >= 1
{
  var days := daysSince1980;
  year := 1980;
  while days > 365
  {
    if IsLeapYear(year) {
      if days > 366 {
        days := days - 366;
        year := year + 1;
      }
    } else {
      days := days - 365;
      year := year + 1;
    }
  }
  dayOfYear := days;
}
*/
