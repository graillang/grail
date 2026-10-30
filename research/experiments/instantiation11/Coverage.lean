import Shapes

namespace GrailCore.Coverage

-- Address/target identity is a different domain from lifetime support.
theorem no_fresh_cover (outputs originals : List Nat) (unique : outputs.Nodup)
    (fromInputs : outputs ⊆ originals) (sameCount : outputs.length = originals.length) :
    originals ⊆ outputs := by
  intro target present
  by_cases found : target ∈ outputs
  · exact found
  · have longer : (target :: outputs).length ≤ originals.length :=
      (List.nodup_cons.mpr ⟨found, unique⟩).length_le_of_subset (by
        intro value hv
        rcases List.mem_cons.mp hv with hv | hv
        · exact hv ▸ present
        · exact fromInputs hv)
    simp only [List.length_cons] at longer
    rw [sameCount] at longer
    exact False.elim (Nat.not_succ_le_self _ longer)

-- Uniform mathematical post-bound update, not permission to copy arbitrary T.
def overwrite (targets : List Nat) (store : Nat → β) (bound : β) : Nat → β :=
  match targets with
  | [] => store
  | first :: rest => write (overwrite rest store bound) first bound

theorem overwrite_member (targets : List Nat) (store : Nat → β) (bound : β) :
    ∀ target, target ∈ targets → overwrite targets store bound target = bound := by
  induction targets with
  | nil => intro target h; cases h
  | cons first rest ih =>
    intro target h
    rcases List.mem_cons.mp h with h | h
    · subst target; simp [overwrite, write]
    · by_cases same : target = first
      · simp [overwrite, write, same]
      · simpa [overwrite, write, same] using ih target h

theorem complete_transfer (outputs originals : List Nat) (unique : outputs.Nodup)
    (fromInputs : outputs ⊆ originals) (sameCount : outputs.length = originals.length)
    (store : Nat → β) (bound : β) :
    ∀ target, target ∈ originals → overwrite outputs store bound target = bound := by
  intro target present
  exact overwrite_member outputs store bound target
    (no_fresh_cover outputs originals unique fromInputs sameCount present)

theorem arity_without_cover :
    [0, 2].Nodup ∧ [0, 2].length = [0, 1].length ∧ ¬ ([0, 1] ⊆ [0, 2]) := by decide

theorem duplication_without_cover :
    [0, 0] ⊆ [0, 1] ∧ [0, 0].length = [0, 1].length ∧ ¬ ([0, 1] ⊆ [0, 0]) := by decide

def lifetimeSupport (targets : List Nat) (root : Nat) : Prop :=
  root = 0 ∧ ∃ target, target ∈ targets ∧ target < 2

theorem lifetime_union_same (root : Nat) :
    lifetimeSupport [0, 1] root ↔ lifetimeSupport [0, 2] root := by
  constructor
  · rintro ⟨h, _⟩
    exact ⟨h, 0, by decide, by decide⟩
  · rintro ⟨h, _⟩
    exact ⟨h, 0, by decide, by decide⟩

#print axioms no_fresh_cover
#print axioms overwrite_member
#print axioms complete_transfer
#print axioms arity_without_cover
#print axioms duplication_without_cover
#print axioms lifetime_union_same
end GrailCore.Coverage
