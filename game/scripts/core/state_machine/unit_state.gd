class_name UnitState extends "res://scripts/core/state_machine/state.gd"
##
## UnitState — base class for unit-specific states.
##
## Per docs/STATE_MACHINE_CONTRACT.md §2.2: the concrete unit states (Idle,
## Moving, Attacking, Gathering, Constructing, Casting, Dying) all extend
## UnitState. UnitState is intentionally thin — it exists as a typed seam so
## that AI-controller states (EconomyState, BuildUpState, ...) can extend
## State directly without picking up unit-only conventions.
##
## Concrete subclasses ship Phase 1+ in `game/scripts/units/states/`.
## Phase 0 ships only this base class plus a test-only stub used to verify
## the StateMachine lifecycle.
