using System.Numerics;

// BinarySearch was written and proven correct in Dafny (BinarySearch.dfy), then translated to C#
// (Dafny.cs) by the build. Dafny's int is unbounded, so the array and key are BigInteger.

// BinarySearch requires a sorted array (proven for Dafny callers; up to us here in C#).
BigInteger[] sorted = { 2, 3, 7, 9, 12, 15 };
Console.WriteLine($"Sorted:  {string.Join(", ", sorted)}");
foreach (BigInteger key in new BigInteger[] { 7, 15, 5 })
{
    int index = _module.__default.BinarySearch(sorted, key);
    Console.WriteLine(index >= 0 ? $"Search {key}: found at index {index}" : $"Search {key}: not found");
}
Console.WriteLine();

// The bug Dafny rejects, in plain C#: no warning, no exception, just a wrong (negative) midpoint.
int low = Int32.MaxValue;
int high = Int32.MaxValue;
int i32 = (low + high) / 2;
Console.WriteLine($"C# (low + high) / 2 with both = int.MaxValue: {i32}");
