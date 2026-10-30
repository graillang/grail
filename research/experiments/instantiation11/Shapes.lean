import Routes

namespace GrailCore.Shapes

-- Dependency shape only: unit also terminates a record-field spine.
inductive Shape where
  | unit
  | view
  | var (name : String)
  | field (name : String) (child rest : Shape)
  | many (child : Shape)

def substitute (σ : String → Shape) : Shape → Shape
  | .unit => .unit
  | .view => .view
  | .var name => σ name
  | .field name child rest => .field name (substitute σ child) (substitute σ rest)
  | .many child => .many (substitute σ child)

def lookup : Shape → String → Option Shape
  | .field name child rest, key => if key = name then some child else lookup rest key
  | .many child, key => if key = "*" then some child else none
  | _, _ => none

def focus : Shape → List String → Option Shape
  | ty, [] => some ty
  | ty, key :: rest => (lookup ty key).bind (fun child => focus child rest)

theorem lookup_substitute (σ : String → Shape) (ty : Shape) (key : String)
    (payload : Shape) (found : lookup ty key = some payload) :
    lookup (substitute σ ty) key = some (substitute σ payload) := by
  induction ty generalizing payload with
  | unit => simp [lookup] at found
  | view => simp [lookup] at found
  | var name => simp [lookup] at found
  | field name child rest _ ih =>
    by_cases h : key = name
    · simp [lookup, h] at found
      subst payload
      simp [substitute, lookup, h]
    · simp [lookup, h] at found
      simpa [substitute, lookup, h] using ih payload found
  | many child _ =>
    by_cases h : key = "*"
    · simp [lookup, h] at found
      subst payload
      simp [substitute, lookup, h]
    · simp [lookup, h] at found

theorem at_substitute (σ : String → Shape) (ty : Shape) (path : List String)
    (payload : Shape) (found : focus ty path = some payload) :
    focus (substitute σ ty) path = some (substitute σ payload) := by
  induction path generalizing ty with
  | nil =>
    simp [focus] at found
    subst payload
    rfl
  | cons key rest ih =>
    cases h : lookup ty key with
    | none => simp [focus, h] at found
    | some child =>
      simp [focus, h] at found
      have replaced := lookup_substitute σ ty key child h
      simpa [focus, replaced] using ih child found

theorem at_append (ty : Shape) (base suffix : List String) (payload : Shape)
    (found : focus ty base = some payload) : focus ty (base ++ suffix) = focus payload suffix := by
  induction base generalizing ty with
  | nil =>
    simp [focus] at found
    subst payload
    rfl
  | cons key rest ih =>
    cases h : lookup ty key with
    | none => simp [focus, h] at found
    | some child =>
      simp [focus, h] at found
      simpa [focus, h] using ih child found

def Carries : Shape → Prop
  | .view | .var _ => True
  | _ => False

def Allowed (ty : Shape) (path : List String) : Prop :=
  ∃ leaf, focus ty path = some leaf ∧ Carries leaf

theorem same_var_descendants (σ : String → Shape) (source target : Shape)
    (src dst : List String) (name : String)
    (sourceAt : focus source src = some (.var name))
    (targetAt : focus target dst = some (.var name)) (suffix : List String) :
    Allowed (substitute σ source) (src ++ suffix) ↔
    Allowed (substitute σ target) (dst ++ suffix) := by
  have hs := at_substitute σ source src (.var name) sourceAt
  have ht := at_substitute σ target dst (.var name) targetAt
  unfold Allowed
  rw [at_append _ _ _ _ hs, at_append _ _ _ _ ht]

theorem generic_route_supported (σ : String → Shape) (source target : Shape)
    (src dst : List String) (name : String) (tree : Routes.Tree String R)
    (sourceAt : focus source src = some (.var name))
    (targetAt : focus target dst = some (.var name))
    (valid : Routes.SupportedOn (Allowed (substitute σ source)) tree) :
    Routes.SupportedOn (Allowed (substitute σ target)) (Routes.forward dst src tree) :=
  Routes.forward_supported src dst tree _ _ valid
    (fun suffix => (same_var_descendants σ source target src dst name sourceAt targetAt suffix).mp)

theorem unknown_path_can_appear :
    focus (.var "T") ["x"] = none ∧
    focus (substitute (fun _ => .field "x" .view .unit) (.var "T")) ["x"] = some .view := by
  simp [focus, lookup, substitute]

theorem distinct_vars_can_diverge :
    let σ := fun name => if name = "T" then Shape.field "x" .view .unit else .unit
    Allowed (substitute σ (.var "T")) ["x"] ∧ ¬ Allowed (substitute σ (.var "U")) ["x"] := by
  change Allowed (.field "x" .view .unit) ["x"] ∧ ¬ Allowed .unit ["x"]
  constructor
  · exact ⟨.view, rfl, trivial⟩
  · rintro ⟨leaf, h, _⟩
    cases h

#print axioms lookup_substitute
#print axioms at_substitute
#print axioms at_append
#print axioms same_var_descendants
#print axioms generic_route_supported
#print axioms unknown_path_can_appear
#print axioms distinct_vars_can_diverge
end GrailCore.Shapes
