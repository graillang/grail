// Abstract cancellation/buffer-lifetime model, NOT a Grail runtime implementation.
module cancel_scope {
  var phase: int
  var alive: bool
  var loan: bool
  var generation: int
  var loanGeneration: int

  action init = all {
    phase' = 0, alive' = true, loan' = false,
    generation' = 0, loanGeneration' = 0,
  }
  action spawn = all {
    phase == 0,
    phase' = 1, alive' = alive, loan' = true,
    generation' = generation, loanGeneration' = generation,
  }
  action cancel = all {
    phase == 1,
    phase' = 2, alive' = alive, loan' = loan,
    generation' = generation, loanGeneration' = loanGeneration,
  }
  action acknowledge = all {
    phase == 2,
    phase' = 3, alive' = alive, loan' = false,
    generation' = generation, loanGeneration' = loanGeneration,
  }
  action release = all {
    or { phase == 0, phase == 3 },
    phase' = 4, alive' = false, loan' = loan,
    generation' = generation + 1, loanGeneration' = loanGeneration,
  }
  action prematureRelease = all {
    phase == 2,
    phase' = 4, alive' = false, loan' = loan,
    generation' = generation + 1, loanGeneration' = loanGeneration,
  }
  action reallocateWhilePending = all {
    phase == 2,
    phase' = phase, alive' = alive, loan' = loan,
    generation' = generation + 1, loanGeneration' = loanGeneration,
  }
  action idle = all {
    phase' = phase, alive' = alive, loan' = loan,
    generation' = generation, loanGeneration' = loanGeneration,
  }
  action step_safe = any { spawn, cancel, acknowledge, release, idle }
  action step_early_release = any { spawn, cancel, acknowledge, release, prematureRelease, idle }
  action step_reallocate = any { spawn, cancel, acknowledge, release, reallocateWhilePending, idle }
  val validLoan = loan implies (alive and loanGeneration == generation)
}
