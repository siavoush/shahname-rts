extends Node
##
## CommandPool — pre-allocated pool of Command objects.
##
## Per docs/STATE_MACHINE_CONTRACT.md §2.5 / §3.1: Command objects are pooled
## to avoid per-tick allocation. A 50-vs-50 battle at 30 Hz with frequent
## queue churn would otherwise burn thousands of throwaway RefCounteds per
## second.
##
## Capacity sizing: per the contract, ~32 commands × ~250 max units = 8000
## entries upper bound. We pre-allocate lazily — the pool starts empty and
## grows on demand up to MAX_POOLED. Returned Commands are reset (kind
## cleared, payload cleared) and re-shelved.
##
## API:
##   rent() -> Command       # caller takes ownership; must return when done
##   return_to_pool(cmd)     # reset and re-shelve; idempotent on already-shelved
##
## Never call Command.new() directly outside this pool. The lint rule for
## that lives in the contract; we don't add a CI gate yet (no consumers
## exist this session) but the discipline is documented.

const MAX_POOLED: int = 8000   # safety cap; warn beyond

var _free: Array = []          # Array[Command] — reusable instances
var _outstanding: int = 0      # currently-rented (debug introspection)


# Class reference. Resolved at parse time via `preload` to avoid a
# class_name resolution race during autoload boot — autoloads parse before
# the project-wide class_name registry is populated, so a top-level
# `Command.new()` reference can fail with "Could not find type" on cold
# load even though `class_name Command` exists on the target script.
const _CommandClass: Script = preload("res://scripts/core/state_machine/command.gd")


## Acquire a fresh Command. Returns a pooled instance if available, else
## allocates one. The caller owns the instance until it returns it.
##
## Returns the Command typed loosely — it IS a Command (class_name on the
## preloaded script), but typed as Object here so this autoload doesn't
## hard-depend on the class_name resolver during boot.
func rent() -> Object:
	var cmd: Object
	if _free.is_empty():
		cmd = _CommandClass.new()
	else:
		cmd = _free.pop_back()
	cmd.call(&"reset")
	_outstanding += 1
	return cmd


## Return a Command to the pool. The Command is reset (kind cleared, payload
## cleared) before re-shelving. Calls beyond MAX_POOLED drop the instance
## (the GC collects it) and emit a debug warning so we notice runaway pools.
func return_to_pool(cmd: Object) -> void:
	if cmd == null:
		return
	cmd.call(&"reset")
	_outstanding = max(_outstanding - 1, 0)
	if _free.size() >= MAX_POOLED:
		push_warning("CommandPool: MAX_POOLED reached; dropping returned command")
		return
	_free.append(cmd)


## Diagnostic: number of currently-rented commands (helpful in tests + F3 overlay).
func outstanding() -> int:
	return _outstanding


## Diagnostic: number of pooled (free) commands.
func free_count() -> int:
	return _free.size()


## Test/lifecycle helper.
func reset() -> void:
	_free.clear()
	_outstanding = 0
