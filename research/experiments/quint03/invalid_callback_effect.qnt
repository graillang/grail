module invalid_callback_effect {
  var counter: int
  pure def apply(f, x) = f(x)
  def readCounter(x) = counter + x
  pure val concealedRead = apply(readCounter, 1)
}
