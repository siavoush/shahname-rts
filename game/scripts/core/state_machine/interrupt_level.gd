class_name InterruptLevel extends RefCounted
##
## InterruptLevel — interrupt-priority enum for State.
##
## Per docs/STATE_MACHINE_CONTRACT.md §2.1.
##
##   NONE   — default; damage does not interrupt. Idle, casual movement.
##   COMBAT — damage interrupts. Gathering, non-combat movement, returning.
##   NEVER  — damage cannot interrupt. Constructing, casting, dying.
##
## NEVER blocks damage-driven preemption only. Player replace_command and
## death always win (Contract §3.5, §4).
##
## Why a class_name + RefCounted instead of a top-level `enum` block: GDScript
## enums declared at script-top can only be exported as `int`. Wrapping the
## values in a tiny named class lets us refer to them as
## `InterruptLevel.NEVER` from anywhere in the project without hardcoding the
## integer value or duplicating the enum block in every consumer.

enum {
	NONE,
	COMBAT,
	NEVER,
}
