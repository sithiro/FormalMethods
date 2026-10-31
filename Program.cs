using System.Numerics;

// Max and Min were written and proven correct in Dafny (Max.dfy, Min.dfy), then translated
// together to C# (Dafny.cs) by the build. Dafny's int is unbounded, so they use BigInteger.
BigInteger[] numbers = { 3, 9, 2, 7 };

BigInteger max = _module.__default.Max(numbers);
BigInteger min = _module.__default.Min(numbers);

Console.WriteLine($"Numbers: {string.Join(", ", numbers)}");
Console.WriteLine($"Max:     {max}");
Console.WriteLine($"Min:     {min}");
