// Apple "goto fail", iOS and OS X, fixed February 2014 (CVE-2014-1266).
//
// SSLVerifySignedServerKeyExchange checks that a secure server really signed its key exchange. In C:
//
//     if ((err = SSLHashSHA1.update(&hashCtx, &serverRandom)) != 0)
//         goto fail;
//     if ((err = SSLHashSHA1.update(&hashCtx, &signedParams)) != 0)
//         goto fail;
//         goto fail;                        <- duplicated line: always runs, err is still 0
//     ... the signature check, never reached ...
//     fail:
//         return err;
//
// The second `goto fail;` jumps to `return err` with err == 0, meaning "success", and the signature
// is never checked. Any network attacker could impersonate a secure server. The code ran without a
// crash or error; it just gave the wrong answer.
// See https://dwheeler.com/essays/apple-goto-fail.html
//
// Unlike the other examples, this is not a crash. Dafny catches it because the `ensures` below states
// the security property: success is only allowed if the signature is valid.

// Toy signature: stands in for the real RSA/ECDSA computation.
function Sign(serverRandom: int, signedParams: int, key: int): int {
  (serverRandom * 31 + signedParams) * key % 65521
}

const ErrSslCrypto := -9809    // errSSLCrypto, the error code the real function returns

// Stands in for SSLHashSHA1.update: fails on bad input.
method HashUpdate(part: int) returns (err: int)
  ensures err == 0 || err == ErrSslCrypto
{
  err := if part < 0 then ErrSslCrypto else 0;
}

// Returns 0 only if the server's signature is valid.
method VerifySignedServerKeyExchange(serverRandom: int, signedParams: int, signature: int, key: int)
  returns (err: int)
  ensures err == 0 ==> signature == Sign(serverRandom, signedParams, key)   // the security promise
{
  err := HashUpdate(serverRandom);
  if err != 0 { return; }                                  // goto fail;
  err := HashUpdate(signedParams);
  if err != 0 { return; }                                  // goto fail;
  err := if signature == Sign(serverRandom, signedParams, key) then 0 else ErrSslCrypto;
}

// TRY IT: below is Apple's version, with the duplicated line. Dafny has no goto; `return;` does the
// same thing here (jump to the end and return err). Delete the line that holds only /* and the line
// that holds only */ (both are around the method), then run `dotnet build`.
//
// Expected: the build fails before anything runs, with
//
//     GotoFail.dfy(69,2): error : a postcondition could not be proved on this return path
//     Build FAILED.
//
// Why: on that path err is 0, so the method claims success, but nothing on the path checked the
// signature. Dafny cannot prove the promise `err == 0 ==> signature == Sign(...)`, and it points at
// the duplicated line. No test that uses a correctly signed server would ever notice. Put the two
// lines back to make the build pass.
/*
method VerifySignedServerKeyExchangeApple(serverRandom: int, signedParams: int, signature: int, key: int)
  returns (err: int)
  ensures err == 0 ==> signature == Sign(serverRandom, signedParams, key)
{
  err := HashUpdate(serverRandom);
  if err != 0 { return; }
  err := HashUpdate(signedParams);
  if err != 0 { return; }
  return;
  err := if signature == Sign(serverRandom, signedParams, key) then 0 else ErrSslCrypto;
}
*/
