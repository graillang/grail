import Instantiation

namespace GrailCore.Routes

abbrev Tree (Label R : Type) := List Label → Roots R

def project (base : List Label) (tree : Tree Label R) : Tree Label R :=
  fun suffix => tree (base ++ suffix)

-- Relational specification: retain the same descendant suffix, not a root union.
def forward (dst src : List Label) (tree : Tree Label R) : Tree Label R :=
  fun path root => ∃ suffix, path = dst ++ suffix ∧ tree (src ++ suffix) root

-- The take/drop form corresponds to Python prefix slicing and suffix concatenation.
def sliced [DecidableEq Label] (dst src : List Label) (tree : Tree Label R) : Tree Label R :=
  fun path => if path.take dst.length = dst then tree (src ++ path.drop dst.length) else empty

theorem sliced_iff_forward [DecidableEq Label]
    (dst src path : List Label) (tree : Tree Label R) (root : R) :
    sliced dst src tree path root ↔ forward dst src tree path root := by
  constructor
  · intro h
    by_cases hp : path.take dst.length = dst
    · exact ⟨path.drop dst.length, by simpa [hp] using (List.take_append_drop dst.length path).symm,
        by simpa [sliced, hp] using h⟩
    · simp [sliced, hp, empty] at h
  · rintro ⟨suffix, rfl, h⟩
    simpa [sliced, List.take_left, List.drop_left] using h

theorem descendant_exact :
    project dst (forward dst src tree) suffix root ↔ project src tree suffix root := by
  constructor
  · rintro ⟨other, heq, h⟩
    have same : suffix = other := List.append_cancel_left heq
    simpa [project, same] using h
  · intro h
    exact ⟨suffix, rfl, h⟩

theorem no_unrelated_output (outside : ∀ suffix, path ≠ dst ++ suffix) :
    ¬ forward dst src tree path root := by
  rintro ⟨suffix, h, _⟩
  exact outside suffix h

theorem forward_union :
    forward dst src (fun p => union (a p) (b p)) path root ↔
    union (forward dst src a path) (forward dst src b path) root := by
  constructor
  · rintro ⟨suffix, heq, h⟩
    rcases h with ha | hb
    · exact Or.inl ⟨suffix, heq, ha⟩
    · exact Or.inr ⟨suffix, heq, hb⟩
  · intro h
    rcases h with ⟨suffix, heq, ha⟩ | ⟨suffix, heq, hb⟩
    · exact ⟨suffix, heq, Or.inl ha⟩
    · exact ⟨suffix, heq, Or.inr hb⟩

theorem instantiate_forward :
    Symbolic.instantiate σ (forward dst src tree path) root ↔
    forward dst src (fun p => Symbolic.instantiate σ (tree p)) path root := by
  constructor
  · rintro ⟨source, ⟨suffix, heq, hq⟩, hr⟩
    exact ⟨suffix, heq, source, hq, hr⟩
  · rintro ⟨suffix, heq, source, hq, hr⟩
    exact ⟨source, ⟨suffix, heq, hq⟩, hr⟩

def SupportedOn (allowed : List Label → Prop) (tree : Tree Label R) : Prop :=
  ∀ path root, tree path root → allowed path

theorem forward_supported (src dst : List Label) (tree : Tree Label R)
    (allowedSource allowedTarget : List Label → Prop) (valid : SupportedOn allowedSource tree)
    (compatible : ∀ suffix, allowedSource (src ++ suffix) → allowedTarget (dst ++ suffix)) :
    SupportedOn allowedTarget (forward dst src tree) := by
  rintro path root ⟨suffix, rfl, h⟩
  exact compatible suffix (valid _ _ h)

def replace [DecidableEq Label] (base : List Label) (old incoming : Tree Label R) : Tree Label R :=
  fun path => if path.take base.length = base then incoming (path.drop base.length) else old path

theorem replace_project [DecidableEq Label]
    (base suffix : List Label) (old incoming : Tree Label R) :
    project base (replace base old incoming) suffix = incoming suffix := by
  simp [project, replace]

theorem replace_outside [DecidableEq Label]
    (base path : List Label) (old incoming : Tree Label R)
    (outside : path.take base.length ≠ base) :
    replace base old incoming path = old path := by
  simp [replace, outside]

#print axioms sliced_iff_forward
#print axioms descendant_exact
#print axioms no_unrelated_output
#print axioms forward_union
#print axioms instantiate_forward
#print axioms forward_supported
#print axioms replace_project
#print axioms replace_outside
end GrailCore.Routes
