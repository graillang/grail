import Coverage

namespace GrailCore.Refinement

structure Interval (κ : Type) where
  may : Roots κ
  must : Roots κ

def Consistent (c : Interval κ) : Prop := ∀ k, c.must k → c.may k

def Models (c : Interval κ) (actual : Roots κ) : Prop :=
  (∀ k, actual k → c.may k) ∧ (∀ k, c.must k → actual k)

def Refines (narrow wide : Interval κ) : Prop :=
  (∀ k, narrow.may k → wide.may k) ∧ (∀ k, wide.must k → narrow.must k)

theorem extremes_model (valid : Consistent c) : Models c c.must ∧ Models c c.may := by
  exact ⟨⟨valid, fun _ h => h⟩, ⟨fun _ h => h, valid⟩⟩

theorem refinement_sound (refined : Refines narrow wide) (behavior : Models narrow actual) :
    Models wide actual := by
  constructor
  · intro k h
    exact refined.1 k (behavior.1 k h)
  · intro k h
    exact behavior.2 k (refined.2 k h)

theorem refinement_complete (valid : Consistent narrow)
    (semantic : ∀ actual, Models narrow actual → Models wide actual) : Refines narrow wide := by
  exact ⟨(semantic _ (extremes_model valid).2).1, (semantic _ (extremes_model valid).1).2⟩

theorem refinement_iff_models (valid : Consistent narrow) :
    Refines narrow wide ↔ (∀ actual, Models narrow actual → Models wide actual) := by
  constructor
  · intro refined actual behavior
    exact refinement_sound refined behavior
  · exact refinement_complete valid

#print axioms extremes_model
#print axioms refinement_sound
#print axioms refinement_complete
#print axioms refinement_iff_models
end GrailCore.Refinement
