import Std

/- A pure shared-data dependency model, not an ownership or heap semantics. -/
namespace GrailCore

universe u v
abbrev Roots (ρ : Type v) := ρ → Prop

def empty : Roots ρ := fun _ => False
def union (a b : Roots ρ) : Roots ρ := fun r => a r ∨ b r

def Covered (deps : α → Roots ρ) (xs : List α) (q : Roots ρ) : Prop :=
  ∀ x, x ∈ xs → ∀ r, deps x r → q r

structure State (β : Type u) where
  slots : Nat → β
  saved : β

def write (s : Nat → β) (n : Nat) (x : β) : Nat → β :=
  fun k => if k = n then x else s k

def Related (deps : α → Roots ρ) (s : State (List α)) (q : State (Roots ρ)) : Prop :=
  (∀ n, Covered deps (s.slots n) (q.slots n)) ∧ Covered deps s.saved q.saved

def join (a b : State (Roots ρ)) : State (Roots ρ) :=
  ⟨fun n => union (a.slots n) (b.slots n), union a.saved b.saved⟩

theorem covered_empty : Covered deps [] q := by
  intro x hx
  cases hx

theorem covered_append (ha : Covered deps a qa) (hb : Covered deps b qb) :
    Covered deps (a ++ b) (union qa qb) := by
  intro x hx r hr
  rcases List.mem_append.mp hx with h | h
  · exact Or.inl (ha x h r hr)
  · exact Or.inr (hb x h r hr)

theorem covered_write
    (hs : ∀ k, Covered deps (s k) (q k)) (hx : Covered deps x qx) :
    ∀ k, Covered deps (write s n x k) (write q n qx k) := by
  intro k
  by_cases h : k = n
  · simpa [write, h] using hx
  · simpa [write, h] using hs k

theorem related_join_left (h : Related deps s a) : Related deps s (join a b) := by
  constructor
  · intro n x hx r hr
    exact Or.inl (h.1 n x hx r hr)
  · intro x hx r hr
    exact Or.inl (h.2 x hx r hr)

theorem related_join_right (h : Related deps s b) : Related deps s (join a b) := by
  constructor
  · intro n x hx r hr
    exact Or.inr (h.1 n x hx r hr)
  · intro x hx r hr
    exact Or.inr (h.2 x hx r hr)

inductive Cmd where
  | skip
  | clear (slot : Nat)
  | append (slot input : Nat)
  | replace (slot input : Nat)
  | take (slot : Nat)
  | swap (left right : Nat)
  | forget
  | seq (first second : Cmd)
  | choice (left right : Cmd)

-- Every concrete rule operates on contents, not abstract dependencies.
inductive Exec (inputs : Nat → List α) : Cmd → State (List α) → State (List α) → Prop where
  | skip : Exec inputs .skip s s
  | clear : Exec inputs (.clear n) s {s with slots := write s.slots n []}
  | append : Exec inputs (.append n i) s
      {s with slots := write s.slots n (s.slots n ++ inputs i)}
  | replace : Exec inputs (.replace n i) s ⟨write s.slots n (inputs i), s.slots n⟩
  | take : Exec inputs (.take n) s ⟨write s.slots n [], s.slots n⟩
  | swap : Exec inputs (.swap a b) s
      {s with slots := write (write s.slots a (s.slots b)) b (s.slots a)}
  | forget : Exec inputs .forget s {s with saved := []}
  | seq : Exec inputs a s t → Exec inputs b t z → Exec inputs (.seq a b) s z
  | left : Exec inputs a s t → Exec inputs (.choice a b) s t
  | right : Exec inputs b s t → Exec inputs (.choice a b) s t

def analyze (inputs : Nat → Roots ρ) : Cmd → State (Roots ρ) → State (Roots ρ)
  | .skip, q => q
  | .clear n, q => {q with slots := write q.slots n empty}
  | .append n i, q => {q with slots := write q.slots n (union (q.slots n) (inputs i))}
  | .replace n i, q => ⟨write q.slots n (inputs i), q.slots n⟩
  | .take n, q => ⟨write q.slots n empty, q.slots n⟩
  | .swap a b, q => {q with slots := write (write q.slots a (q.slots b)) b (q.slots a)}
  | .forget, q => {q with saved := empty}
  | .seq a b, q => analyze inputs b (analyze inputs a q)
  | .choice a b, q => join (analyze inputs a q) (analyze inputs b q)

-- Unbounded in program size, payload values, list lengths, slots, roots and branch choices.
theorem preservation (inputBound : ∀ i, Covered deps (inputs i) (qinputs i))
    (run : Exec inputs c s t) :
    ∀ q, Related deps s q → Related deps t (analyze qinputs c q) := by
  induction run with
  | skip => intro q h; exact h
  | clear =>
    intro q h
    exact ⟨covered_write h.1 covered_empty, h.2⟩
  | append =>
    intro q h
    exact ⟨covered_write h.1 (covered_append (h.1 _) (inputBound _)), h.2⟩
  | replace =>
    intro q h
    exact ⟨covered_write h.1 (inputBound _), h.1 _⟩
  | take =>
    intro q h
    exact ⟨covered_write h.1 covered_empty, h.1 _⟩
  | swap =>
    intro q h
    exact ⟨covered_write (covered_write h.1 (h.1 _)) (h.1 _), h.2⟩
  | forget =>
    intro q h
    exact ⟨h.1, covered_empty⟩
  | seq _ _ ih1 ih2 =>
    intro q h
    exact ih2 _ (ih1 _ h)
  | left _ ih =>
    intro q h
    exact related_join_left (ih _ h)
  | right _ ih =>
    intro q h
    exact related_join_right (ih _ h)

def Below (a b : State (Roots ρ)) : Prop :=
  (∀ n r, a.slots n r → b.slots n r) ∧ (∀ r, a.saved r → b.saved r)

-- A public contract may safely be more conservative than the derived post-state.
theorem public_bound (h : Related deps s a) (widen : Below a b) : Related deps s b := by
  constructor
  · intro n x hx r hr
    exact widen.1 n r (h.1 n x hx r hr)
  · intro x hx r hr
    exact widen.2 r (h.2 x hx r hr)

-- Producer coverage and a checked upper bound compose without exposing concrete contents.
theorem checked_contract (inputBound : ∀ i, Covered deps (inputs i) (qinputs i))
    (run : Exec inputs c s t) (initial : Related deps s q)
    (published : Below (analyze qinputs c q) advertised) : Related deps t advertised :=
  public_bound (preservation inputBound run q initial) published

-- Applies only to the tracked state, not hidden inputs, closures, operations or owners.
theorem absent_root (h : Related deps s q)
    (absent : (∀ n, ¬ q.slots n root) ∧ ¬ q.saved root) :
    (∀ n x, x ∈ s.slots n → ¬ deps x root) ∧ (∀ x, x ∈ s.saved → ¬ deps x root) := by
  constructor
  · intro n x hx hr
    exact absent.1 n (h.1 n x hx root hr)
  · intro x hx hr
    exact absent.2 (h.2 x hx root hr)

-- Validity of tracked data is conditional on the truth of deps and the live-root bound.
theorem tracked_valid (live : Roots ρ) (h : Related deps s q)
    (liveBound : (∀ n r, q.slots n r → live r) ∧ (∀ r, q.saved r → live r)) :
    (∀ n x, x ∈ s.slots n → ∀ r, deps x r → live r) ∧
    (∀ x, x ∈ s.saved → ∀ r, deps x r → live r) := by
  constructor
  · intro n x hx r hr
    exact liveBound.1 n r (h.1 n x hx r hr)
  · intro x hx r hr
    exact liveBound.2 r (h.2 x hx r hr)

-- Closed counterexamples: retained source 0 cannot be certified as empty or as source 1.
theorem forged_empty_is_false :
    ¬ Covered (fun (token root : Nat) => token = root) [0] empty := by
  intro claimed
  exact claimed 0 (by simp) 0 rfl

theorem wrong_old_return_is_false :
    ¬ Covered (fun (token root : Nat) => token = root) [0] (fun root => root = 1) := by
  intro claimed
  have h : (0 : Nat) = 1 := claimed 0 (by simp) 0 rfl
  exact Nat.noConfusion h

#print axioms preservation
#print axioms checked_contract
#print axioms forged_empty_is_false
#print axioms wrong_old_return_is_false
#print axioms public_bound
#print axioms absent_root
#print axioms tracked_valid
end GrailCore
