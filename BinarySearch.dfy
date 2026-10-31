// Binary search with 32-bit integers, like Java's and C#'s.
//
// Java's Arrays.binarySearch computed the midpoint as (low + high) / 2. When low + high exceeds
// int.MaxValue (arrays of about a billion elements or more) the sum overflows to a negative number
// and the search crashes. Tests never hit it; it shipped for years. See
// https://research.google/blog/extra-extra-read-all-about-it-nearly-all-binary-searches-and-mergesorts-are-broken/
//
// Dafny rejects that version at build time:
//   Error: result of operation might violate newtype constraint for 'int32'
// The midpoint below, low + (high - low) / 2, is the fix and verifies.

// Dafny's int is unbounded; this restricts values to a 32-bit range so overflow is checked.
newtype int32 = x: int | -0x8000_0000 <= x < 0x8000_0000

// Returns an index of key in a, or -1 if key is not in a.
method BinarySearch(a: array<int>, key: int) returns (index: int32)
  requires a.Length < 0x8000_0000                                  // indexes fit in int32
  requires forall i, j :: 0 <= i < j < a.Length ==> a[i] <= a[j]   // a is sorted
  ensures 0 <= index ==> index as int < a.Length && a[index] == key
  ensures index < 0 ==> index == -1 && forall i :: 0 <= i < a.Length ==> a[i] != key
{
  var low: int32 := 0;
  var high: int32 := a.Length as int32 - 1;
  while low <= high
    invariant 0 <= low as int <= a.Length
    invariant -1 <= high as int < a.Length
    invariant forall i :: 0 <= i < low as int ==> a[i] < key           // key is not left of low
    invariant forall i :: high as int < i < a.Length ==> a[i] > key    // key is not right of high
  {
    var mid: int32 := low + (high - low) / 2;
    // ^ The fix. low <= high, so (high - low) / 2 never exceeds high and mid stays in int32 range.
    //
    // TRY IT: the original Java line was  int mid = (low + high) / 2;
    // In Dafny that is the line below. Swap it with line 30 (keep it on line 30) and run `dotnet build`:
    //
    //     var mid: int32 := (low + high) / 2;
    //
    // Expected: the build fails before anything runs, with
    //
    //     BinarySearch.dfy(30,27): error : result of operation might violate newtype constraint for 'int32'
    //     Dafny program verifier finished with 6 verified, 1 error
    //     Build FAILED.
    //
    // (30,27) is line 30, column 27, inside (low + high). Visual Studio lists it in the Error List.
    //
    // Why: low and high can each be up to int.MaxValue - 1, so low + high can exceed int.MaxValue.
    // In Java and C# the sum then wraps to a negative number and a[mid] throws, but only for arrays of
    // about a billion elements or more, so no ordinary test ever sees it. Dafny checks the + against
    // every possible low and high and reports it at once. Put line 30 back to make the build pass.
    if a[mid] < key {
      low := mid + 1;
    } else if a[mid] > key {
      high := mid - 1;
    } else {
      return mid;
    }
  }
  return -1;
}
