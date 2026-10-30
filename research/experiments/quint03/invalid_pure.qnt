module invalid_pure {
  var counter: int
  pure def peek(x) = counter + x
}
