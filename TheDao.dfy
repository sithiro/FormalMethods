// The DAO, an Ethereum investment fund, June 2016.
//
// To withdraw, The DAO sent the investor's ether first and set their balance to zero last. Sending
// ether to a contract runs that contract's code, so an attacker's contract, on receiving the
// payment, called the withdraw function again, before its balance had been cleared. Each nested
// call saw the same balance and paid it again. About 3.6 million ether was drained; Ethereum
// rewrote its own history with a hard fork to recover it. Every line of the function was correct on
// its own; the bug was the order.
// See https://labs.withsecure.com/publications/the-hack-that-changed-the-blockchain-perspective
//
// Unlike the other examples, this bug is about state across calls. The class below states a rule
// that must hold whenever outside code can run: the fund can always cover what it owes. Dafny checks
// the rule at every call, including the call back in from the recipient.

class Dao {
  var balance: int      // what the fund owes this investor
  var vault: int        // ether the fund actually holds (from all investors)

  constructor(deposit: int, othersDeposits: int)
    requires deposit >= 0 && othersDeposits >= 0
    ensures Solvent() && balance == deposit && vault == deposit + othersDeposits
  {
    balance := deposit;
    vault := deposit + othersDeposits;
  }

  // The rule: the fund holds at least what it owes this investor.
  predicate Solvent()
    reads this
  {
    0 <= balance <= vault
  }

  // Pays the investor their balance. Sending ether runs the recipient's code, which may call Withdraw
  // again; `reentries` is how many times it does (0 for an honest investor).
  method Withdraw(reentries: nat)
    requires Solvent()
    modifies this
    ensures Solvent()
    decreases reentries
  {
    var amount := balance;
    balance := 0;                                   // the fix: record the withdrawal first...
    vault := vault - amount;                        // ...then send the ether
    if reentries > 0 { Withdraw(reentries - 1); }   // the recipient's code calls back in
  }

  // TRY IT: below is The DAO's order: send first, record the withdrawal last. Delete the line that
  // holds only /* and the line that holds only */ (both are around the method), then run
  // `dotnet build`.
  //
  // Expected: the build fails before anything runs, with
  //
  //     TheDao.dfy(68,34): error : a precondition for this call could not be proved
  //     Build FAILED.
  //
  // Why: when the recipient calls back in, the ether has left the vault but the balance still says
  // it is owed, so balance <= vault no longer holds. Dafny points at the call back in: outside code
  // runs while the fund's books are wrong. Put the two lines back to make the build pass.
/*
  method WithdrawDao(reentries: nat)
    requires Solvent()
    modifies this
    ensures Solvent()
    decreases reentries
  {
    var amount := balance;
    vault := vault - amount;
    if reentries > 0 { WithdrawDao(reentries - 1); }
    balance := 0;
  }
*/
}
