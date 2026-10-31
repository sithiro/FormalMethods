using System.Numerics;

// Each example was written and proven correct in Dafny (*.dfy), then translated to C# (Dafny.cs)
// by the build. Each one is shown next to the original bug written in plain C#, which compiles
// without a warning. Dafny's int is unbounded, so it appears here as BigInteger.

// --- 1. Binary search (Java's Arrays.binarySearch overflow) -------------------------------------
// BinarySearch requires a sorted array (proven for Dafny callers; up to us here in C#).
BigInteger[] sorted = { 2, 3, 7, 9, 12, 15 };
int found = _module.__default.BinarySearch(sorted, 7);
int missing = _module.__default.BinarySearch(sorted, 5);
Console.WriteLine($"Dafny: search [{string.Join(", ", sorted)}] for 7 = index {found}, for 5 = {missing} (not found)");

// The original midpoint in C#, with search bounds an array of ~2 billion elements reaches.
int low = 1_500_000_000;
int high = 2_000_000_000;
int mid = (low + high) / 2;
Console.WriteLine($"C#:    (low + high) / 2 for {low:N0} and {high:N0} = {mid:N0} (no warning, negative index)");
Console.WriteLine();

// --- 2. Zune freeze (31 Dec 2008: infinite loop on the last day of a leap year) ------------------
BigInteger zuneDay = (new DateTime(2008, 12, 31) - new DateTime(1980, 1, 1)).Days + 1;
_module.__default.DaysToYear(zuneDay, out BigInteger year, out BigInteger dayOfYear);
Console.WriteLine($"Dafny: day {zuneDay} since 1980 is day {dayOfYear} of {year}");

// The original Zune loop in C#. Capped here so the demo finishes; the Zune had no cap.
long days = (long)zuneDay;
int zuneYear = 1980;
long passes = 0;
while (days > 365 && passes < 1_000_000)
{
    if (DateTime.IsLeapYear(zuneYear))
    {
        if (days > 366)
        {
            days -= 366;
            zuneYear += 1;
        }
    }
    else
    {
        days -= 365;
        zuneYear += 1;
    }
    passes++;
}
Console.WriteLine(days > 365
    ? $"C#:    original loop still running after {passes:N0} passes (stuck at {zuneYear}, day {days})"
    : $"C#:    original loop finished: day {days} of {zuneYear}");
Console.WriteLine();

// --- 3. Ariane 5 (1996: 64-bit value converted to 16 bits) --------------------------------------
long horizontalBias = 40_000;   // too big for 16 bits (max 32,767)
short safe = _module.__default.ConvertHorizontalBias(horizontalBias);
Console.WriteLine($"Dafny: ConvertHorizontalBias({horizontalBias:N0}) = {safe:N0} (clamped to the 16-bit limit)");
short wrapped = (short)horizontalBias;
Console.WriteLine($"C#:    (short){horizontalBias:N0} = {wrapped:N0} (no warning, wrong sign)");
