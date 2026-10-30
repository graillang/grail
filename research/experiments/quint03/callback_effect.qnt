module callback_effect {
  var counter: int
  pure def apply(f, x) = f(x)
  def readCounter(x) = counter + x
  val actualEffect = apply(readCounter, 1)
}
