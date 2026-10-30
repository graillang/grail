module invalid_double_update {
  var counter: int
  action bad = all { counter' = 1, counter' = 2 }
}
