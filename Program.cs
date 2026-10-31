using System.Numerics;
using System.Text;

// Each example was written and proven correct in Dafny (*.dfy), then translated to C# (Dafny.cs)
// by the build. Each one is shown next to the original bug written in plain C#, which compiles
// without an error (and, except for goto fail, without a warning). Dafny's int is unbounded, so it
// appears here as BigInteger.

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
Console.WriteLine();

// --- 4. Heartbleed (2014: heartbeat length never checked against the payload) -------------------
byte[] payload = Encoding.ASCII.GetBytes("HAT");
// What sat next to the payload in the server's memory. C# arrays are bounds-checked, so to show
// what C did, the payload and its neighbours are modelled as one buffer, as in OpenSSL's heap.
byte[] serverMemory = Encoding.ASCII.GetBytes("HATuser=admin;password=hunter2");
int claimedLength = serverMemory.Length;
byte[] reply = _module.__default.HeartbeatResponse(payload, claimedLength);
Console.WriteLine($"Dafny: heartbeat \"HAT\" claiming {claimedLength} bytes = \"{Encoding.ASCII.GetString(reply)}\" (rejected: claimed more than it sent)");
byte[] leaked = new byte[claimedLength];
Array.Copy(serverMemory, 0, leaked, 0, claimedLength);   // the original: copy claimedLength bytes, unchecked
Console.WriteLine($"C#:    heartbeat \"HAT\" claiming {claimedLength} bytes = \"{Encoding.ASCII.GetString(leaked)}\" (leaked memory)");
Console.WriteLine();

// --- 5. Apple goto fail (2014: a duplicated line skipped the signature check) -------------------
BigInteger serverRandom = 1234, signedParams = 5678, key = 7;
BigInteger forgedSignature = 42;   // the real one is Sign(1234, 5678, 7) = 45440
BigInteger verdict = _module.__default.VerifySignedServerKeyExchange(serverRandom, signedParams, forgedSignature, key);
Console.WriteLine($"Dafny: verify forged signature = {verdict} ({(verdict == 0 ? "accepted" : "rejected")})");
int appleVerdict = AppleVerify(1234, 5678, 42, 7);
Console.WriteLine($"C#:    verify forged signature = {appleVerdict} ({(appleVerdict == 0 ? "accepted: signature never checked" : "rejected")})");
Console.WriteLine();

// --- 6. USS Yorktown (1997: a zero typed into a database field) --------------------------------
BigInteger total = 1_200, count = 0;
_module.__default.AverageReading(total, count, out bool ok, out BigInteger average);
Console.WriteLine($"Dafny: average of {total:N0} over {count} readings = {(ok ? average.ToString() : "not computed (zero count reported)")}");
int fieldTotal = 1_200, fieldCount = 0;   // values read from a database field at run time
try
{
    Console.WriteLine($"C#:    average = {fieldTotal / fieldCount}");
}
catch (DivideByZeroException)
{
    Console.WriteLine($"C#:    {fieldTotal:N0} / {fieldCount} = DivideByZeroException (no compiler warning; the Yorktown's network crashed)");
}

// Apple's SSLVerifySignedServerKeyExchange logic, translated to C# with the duplicated goto.
// C# flags the skipped line as CS0162 "unreachable code" (silenced here to keep the build clean),
// but a warning is easy to miss; the C original shipped on millions of devices.
static int AppleVerify(int serverRandom, int signedParams, int signature, int key)
{
    const int errSSLCrypto = -9809;
    int err;
    if ((err = HashUpdate(serverRandom)) != 0)
        goto fail;
    if ((err = HashUpdate(signedParams)) != 0)
        goto fail;
        goto fail;
#pragma warning disable CS0162
    err = signature == (serverRandom * 31 + signedParams) * key % 65521 ? 0 : errSSLCrypto;
#pragma warning restore CS0162
fail:
    return err;

    static int HashUpdate(int part) => part < 0 ? errSSLCrypto : 0;
}
