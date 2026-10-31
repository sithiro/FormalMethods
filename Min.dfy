method Min(a: array<int>) returns (m: int)
  requires a.Length > 0
  ensures forall i :: 0 <= i < a.Length ==> m <= a[i]
  ensures exists i :: 0 <= i < a.Length && a[i] == m
{
  m := a[0];
  var k := 1;
  while k < a.Length
    invariant 1 <= k <= a.Length
    invariant forall i :: 0 <= i < k ==> m <= a[i]
    invariant exists i :: 0 <= i < k && a[i] == m
  {
    if a[k] < m { m := a[k]; }
    k := k + 1;
  }
}
