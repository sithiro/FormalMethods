using System.Numerics;
using System.Text;

// Each example was written and proven correct in Dafny (*.dfy), then translated to C# (Dafny.cs)
// by the build. Each one is shown next to the original bug written in plain C#, which compiles
// without an error (and, except for goto fail, without a warning). Dafny's int is unbounded, so it
// appears here as BigInteger.

// --- 1. Binary search (Java's Arrays.binarySearch overflow) -------------------------------------
Title("1. Binary search (Java, 2006): integer overflow in the midpoint");
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
Title("2. Zune freeze (Microsoft, 2008): a loop that never ends");
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
Title("3. Ariane 5 (ESA, 1996): a 64-bit value converted to 16 bits");
long horizontalBias = 40_000;   // too big for 16 bits (max 32,767)
short safe = _module.__default.ConvertHorizontalBias(horizontalBias);
Console.WriteLine($"Dafny: ConvertHorizontalBias({horizontalBias:N0}) = {safe:N0} (clamped to the 16-bit limit)");
short wrapped = (short)horizontalBias;
Console.WriteLine($"C#:    (short){horizontalBias:N0} = {wrapped:N0} (no warning, wrong sign)");
Console.WriteLine();

// --- 4. Heartbleed (2014: heartbeat length never checked against the payload) -------------------
Title("4. Heartbleed (OpenSSL, 2014): reading past the end of the payload");
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
Title("5. Apple goto fail (iOS and OS X, 2014): signature never checked, no crash");
BigInteger serverRandom = 1234, signedParams = 5678, key = 7;
BigInteger forgedSignature = 42;   // the real one is Sign(1234, 5678, 7) = 45440
BigInteger verdict = _module.__default.VerifySignedServerKeyExchange(serverRandom, signedParams, forgedSignature, key);
Console.WriteLine($"Dafny: verify forged signature = {verdict} ({(verdict == 0 ? "accepted" : "rejected")})");
int appleVerdict = AppleVerify(1234, 5678, 42, 7);
Console.WriteLine($"C#:    verify forged signature = {appleVerdict} ({(appleVerdict == 0 ? "accepted: signature never checked" : "rejected")})");
Console.WriteLine();

// --- 6. USS Yorktown (1997: a zero typed into a database field) --------------------------------
Title("6. USS Yorktown (US Navy, 1997): division by zero");
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
Console.WriteLine();

// --- 7. Therac-25 (1985-87: a one-byte safety flag incremented until it wrapped to 0) ------------
Title("7. Therac-25 (1985-87): a wrapped counter switched off a safety check");
byte class3 = 0;
for (int pass = 0; pass < 256; pass++)
    class3 = _module.__default.SetUpTestPass(class3);
Console.WriteLine($"Dafny: Class3 flag after 256 set-up passes = {class3} (collimator check still required)");
byte therac = 0;
for (int pass = 0; pass < 256; pass++)
    therac++;                                              // the original: count instead of set
Console.WriteLine($"C#:    Class3 flag after 256 set-up passes = {therac} (wrapped to 0: collimator check skipped)");
Console.WriteLine();

// --- 8. Mars Climate Orbiter (1999: pound-force seconds passed as newton-seconds) ---------------
Title("8. Mars Climate Orbiter (NASA, 1999): pound-force seconds used as newton-seconds");
// The units are separate types only inside Dafny; in C# both become BigInteger, so the C# compiler
// cannot tell them apart. That is why the original hand-off below compiles.
BigInteger firings = 10;
BigInteger impulseLbf = _module.__default.SmallForces(firings);
BigInteger impulseNs = _module.__default.ToNewtonSeconds(impulseLbf);
BigInteger correction = _module.__default.Navigate(firings);
Console.WriteLine($"Dafny: {impulseLbf} lbf·s converted to {impulseNs} N·s, trajectory correction {correction}");
BigInteger mcoCorrection = _module.__default.TrajectoryCorrection(impulseLbf);   // the original: no conversion
Console.WriteLine($"C#:    {impulseLbf} lbf·s used as {impulseLbf} N·s, trajectory correction {mcoCorrection} (about 4.45x too small: the orbiter was lost)");
Console.WriteLine();

// --- 9. Patriot missile (1991: a rounding error that grew with uptime) ---------------------------
Title("9. Patriot missile (US Army, 1991): a rounding error that grew with uptime");
const int tenthsIn100Hours = 100 * 60 * 60 * 10;   // Dhahran's battery had run for over 100 hours
Dafny.BigRational uptime = _module.__default.UptimeSeconds(tenthsIn100Hours);
decimal dafnySeconds = (decimal)uptime.num / (decimal)uptime.den;
Console.WriteLine($"Dafny: clock after 100 hours = {dafnySeconds:N4} s (exact)");
decimal patriotSeconds = tenthsIn100Hours * 0.099999904632568359375m;   // the original: 24-bit 0.1
Console.WriteLine($"C#:    clock after 100 hours = {patriotSeconds:N4} s ({dafnySeconds - patriotSeconds:N4} s behind: the radar looked in the wrong place)");
Console.WriteLine();

// --- 10. The DAO (2016: paid out before recording the withdrawal, so the recipient called back in)
Title("10. The DAO (Ethereum, 2016): paid out before updating the balance");
// An investor with 10 in a fund holding 100 withdraws; their contract calls back in 5 times.
var dao = new _module.Dao();
dao.__ctor(10, 90);
dao.Withdraw(5);
Console.WriteLine($"Dafny: investor owed 10 withdraws, calling back in 5 times: paid {100 - dao.vault}, fund holds {dao.vault}");
BigInteger owed = 10, held = 100;
void DaoWithdraw(int reentries)                    // the original order: send first, record last
{
    BigInteger amount = owed;
    held -= amount;                                // send the ether
    if (reentries > 0) DaoWithdraw(reentries - 1); // the recipient's code calls back in
    owed = 0;                                      // too late
}
DaoWithdraw(5);
Console.WriteLine($"C#:    investor owed 10 withdraws, calling back in 5 times: paid {100 - held}, fund holds {held} (drained)");

// Prints an example's title, underlined.
static void Title(string text)
{
    Console.WriteLine(text);
    Console.WriteLine(new string('-', text.Length));
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
