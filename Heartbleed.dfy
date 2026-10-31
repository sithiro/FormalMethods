// Heartbleed, OpenSSL, disclosed April 2014 (CVE-2014-0160).
//
// A TLS heartbeat request carries a payload plus a field saying how long the payload is. The server
// echoes that many bytes back. OpenSSL trusted the length field without comparing it to the payload
// actually received, so a client could send "HAT" and claim it was 65,535 bytes long. The server
// then copied 65,535 bytes starting at the payload: "HAT" followed by whatever lay next in memory,
// which could include passwords, session cookies and private keys.
// See https://www.theregister.com/2014/04/09/heartbleed_explained/
//
// Dafny requires every array access a[i] to be provably inside the array. It rejects the original.

newtype uint8 = x: int | 0 <= x < 0x100

// Echoes the payload back. A request that claims more bytes than it sent is answered with nothing,
// which is what the OpenSSL fix (and the heartbeat RFC) do.
method HeartbeatResponse(payload: array<uint8>, claimedLength: int) returns (response: array<uint8>)
  requires 0 <= claimedLength < 0x10000                    // the length field is 16 bits
  ensures claimedLength > payload.Length ==> response.Length == 0
  ensures forall i :: 0 <= i < response.Length ==> i < payload.Length && response[i] == payload[i]
{
  if claimedLength > payload.Length {
    return new uint8[0];
  }
  response := new uint8[claimedLength];
  var i := 0;
  while i < claimedLength
    invariant 0 <= i <= claimedLength
    invariant forall j :: 0 <= j < i ==> response[j] == payload[j]
  {
    response[i] := payload[i];
    i := i + 1;
  }
}

// TRY IT: below is the original OpenSSL logic: copy claimedLength bytes, never checking it against
// the payload. Delete the line that holds only /* and the line that holds only */ (both are around
// the method), then run `dotnet build`.
//
// Expected: the build fails before anything runs, with
//
//     Heartbleed.dfy(55,26): error : index out of range
//     Build FAILED.
//
// Why: nothing says claimedLength <= payload.Length, so for some requests i runs past the end of
// payload. Dafny points at payload[i]. In C that read returns other memory (the leak); in C# it
// would throw IndexOutOfRangeException. Put the two lines back to make the build pass.
/*
method HeartbeatResponseOpenSsl(payload: array<uint8>, claimedLength: int) returns (response: array<uint8>)
  requires 0 <= claimedLength < 0x10000
{
  response := new uint8[claimedLength];
  var i := 0;
  while i < claimedLength
    invariant 0 <= i <= claimedLength
  {
    response[i] := payload[i];
    i := i + 1;
  }
}
*/
