import Core

namespace GrailCore.Symbolic

def instantiate (σ : S → Roots R) (q : Roots S) : Roots R :=
  fun r => ∃ s, q s ∧ σ s r

def instantiateState (σ : S → Roots R) (q : State (Roots S)) : State (Roots R) :=
  ⟨fun n => instantiate σ (q.slots n), instantiate σ q.saved⟩

theorem instantiate_empty : instantiate σ empty = empty := by
  funext r
  apply propext
  constructor
  · rintro ⟨_, h, _⟩; exact h
  · intro h; exact False.elim h

theorem instantiate_union : instantiate σ (union a b) =
    union (instantiate σ a) (instantiate σ b) := by
  funext r
  apply propext
  constructor
  · rintro ⟨s, h, hr⟩
    rcases h with ha | hb
    · exact Or.inl ⟨s, ha, hr⟩
    · exact Or.inr ⟨s, hb, hr⟩
  · intro h
    rcases h with ⟨s, ha, hr⟩ | ⟨s, hb, hr⟩
    · exact ⟨s, Or.inl ha, hr⟩
    · exact ⟨s, Or.inr hb, hr⟩

theorem instantiate_write :
    (fun k => instantiate σ (write q n v k)) =
    write (fun k => instantiate σ (q k)) n (instantiate σ v) := by
  funext k
  by_cases h : k = n <;> simp [write, h]

theorem instantiate_join : instantiateState σ (join a b) =
    join (instantiateState σ a) (instantiateState σ b) := by
  simp only [instantiateState, join]
  congr 1
  · funext n; exact instantiate_union
  · exact instantiate_union

-- σ is one immutable substitution for the whole result/post-state tuple.
theorem instantiate_analyze :
    instantiateState σ (analyze inputs c q) =
    analyze (fun i => instantiate σ (inputs i)) c (instantiateState σ q) := by
  induction c generalizing q with
  | skip => rfl
  | clear n => simp [analyze, instantiateState, instantiate_write, instantiate_empty]
  | append n i => simp [analyze, instantiateState, instantiate_write, instantiate_union]
  | replace n i => simp [analyze, instantiateState, instantiate_write]
  | take n => simp [analyze, instantiateState, instantiate_write, instantiate_empty]
  | swap a b => simp [analyze, instantiateState, instantiate_write]
  | forget => simp [analyze, instantiateState, instantiate_empty]
  | seq a b ih1 ih2 => simp only [analyze, ih2, ih1]
  | choice a b ih1 ih2 => simp only [analyze, instantiate_join, ih1, ih2]

theorem instantiate_below (h : Below a b) :
    Below (instantiateState σ a) (instantiateState σ b) := by
  constructor
  · rintro n r ⟨s, hs, hr⟩
    exact ⟨s, h.1 n s hs, hr⟩
  · rintro r ⟨s, hs, hr⟩
    exact ⟨s, h.2 s hs, hr⟩

inductive Pre where
  | slot (n : Nat)
  | input (i : Nat)
  | saved

def singleton (s : S) : Roots S := fun t => t = s

def symbolicInputs (i : Nat) : Roots Pre := singleton (.input i)
def symbolicEntry : State (Roots Pre) := ⟨fun n => singleton (.slot n), singleton .saved⟩
def summary (c : Cmd) : State (Roots Pre) := analyze symbolicInputs c symbolicEntry

def snapshot (inputs : Nat → Roots R) (entry : State (Roots R)) : Pre → Roots R
  | .slot n => entry.slots n
  | .input i => inputs i
  | .saved => entry.saved

theorem instantiate_singleton : instantiate σ (singleton s) = σ s := by
  funext r
  apply propext
  constructor
  · rintro ⟨t, h, hr⟩
    exact h ▸ hr
  · intro hr
    exact ⟨s, rfl, hr⟩

theorem instantiate_preInputs :
    (fun i => instantiate (snapshot inputs entry) (symbolicInputs i)) = inputs := by
  funext i
  simp [symbolicInputs, instantiate_singleton, snapshot]

theorem instantiate_preState :
    instantiateState (snapshot inputs entry) symbolicEntry = entry := by
  cases entry
  simp [instantiateState, symbolicEntry, instantiate_singleton, snapshot]

theorem summary_application :
    instantiateState (snapshot inputs entry) (summary c) = analyze inputs c entry := by
  simp only [summary, instantiate_analyze, instantiate_preInputs, instantiate_preState]

theorem imported_summary (inputBound : ∀ i, Covered deps (inputs i) (qinputs i))
    (run : Exec inputs c s t) (initial : Related deps s entry) :
    Related deps t (instantiateState (snapshot qinputs entry) (summary c)) := by
  rw [summary_application]
  exact preservation inputBound run entry initial

theorem imported_public (inputBound : ∀ i, Covered deps (inputs i) (qinputs i))
    (run : Exec inputs c s t) (initial : Related deps s entry)
    (published : Below (summary c) advertised) :
    Related deps t (instantiateState (snapshot qinputs entry) advertised) :=
  public_bound (imported_summary inputBound run initial) (instantiate_below published)

-- A swapped output depending on pre(slot 0) loses source 0 if that lookup is
-- re-read after overwriting slot 0 with slot 1's support.
theorem changed_snapshot_loses_source :
    let entry : State (Roots Nat) := ⟨fun n => singleton n, empty⟩
    let updated := {entry with slots := write entry.slots 0 (entry.slots 1)}
    instantiate (snapshot (fun _ => empty) entry) (singleton (.slot 0)) 0 ∧
    ¬ instantiate (snapshot (fun _ => empty) updated) (singleton (.slot 0)) 0 := by
  simp [instantiate_singleton, snapshot, write, singleton]

#print axioms instantiate_analyze
#print axioms instantiate_below
#print axioms summary_application
#print axioms imported_summary
#print axioms changed_snapshot_loses_source
#print axioms imported_public
end GrailCore.Symbolic
