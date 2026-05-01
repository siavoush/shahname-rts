class_name CommandQueue extends Object
##
## CommandQueue — per-unit FIFO ring of Commands.
##
## Per docs/STATE_MACHINE_CONTRACT.md §2.4.
##
## Capacity is a hard cap (Constants.COMMAND_QUEUE_CAPACITY = 32). The 33rd
## push drops the *oldest* command and emits a debug warning, protecting
## against accidental Shift-spam in the input layer.
##
## Lifetime: tied to the owning Unit (Object, not RefCounted, so we can free
## it explicitly on unit despawn without ref-cycle gymnastics — Contract §2.4).
##
## Entry rules: only `Unit.replace_command` and `Unit.append_command` are
## sanctioned write paths into the queue (Contract §2.5). Direct `push` /
## `clear` calls outside those helpers will work, but the discipline is to
## go through the helpers so the FSM transition is requested in lockstep.

const _CAPACITY: int = Constants.COMMAND_QUEUE_CAPACITY

# Backing array. We use a pre-allocated, fixed-size Array; _head and _size
# implement the ring. Storing Object refs (Commands are RefCounted —
# Variant container holds a strong ref).
var _ring: Array = []
var _head: int = 0     # index of the oldest live entry
var _size: int = 0     # number of live entries


func _init() -> void:
	# Pre-allocate the backing slots so push/pop are pure index math.
	_ring.resize(_CAPACITY)


## Append a Command to the back of the queue. The 33rd push drops the
## oldest (head) entry — returns it to the pool — and warns once.
##
## Parameter typed as Object (not `Command`) so this script parses cleanly
## under GUT's collection order. Values are still concrete Commands rented
## from CommandPool — see CommandPool.rent().
func push(cmd: Object) -> void:
	if cmd == null:
		return
	if _size == _CAPACITY:
		# Queue full — drop the oldest, return it to the pool, warn.
		var dropped = _ring[_head]
		_ring[_head] = null
		_head = (_head + 1) % _CAPACITY
		_size -= 1
		push_warning("CommandQueue: capacity (%d) reached; oldest command dropped" % _CAPACITY)
		if dropped != null:
			CommandPool.return_to_pool(dropped)
	var tail: int = (_head + _size) % _CAPACITY
	_ring[tail] = cmd
	_size += 1


## Insert at the front (push to head). For AI panic insertions (Contract §2.4).
## Drops the *back* entry on overflow (rare; documented).
func push_front(cmd: Object) -> void:
	if cmd == null:
		return
	if _size == _CAPACITY:
		var tail: int = (_head + _size - 1) % _CAPACITY
		var dropped = _ring[tail]
		_ring[tail] = null
		_size -= 1
		push_warning("CommandQueue: capacity reached on push_front; tail command dropped")
		if dropped != null:
			CommandPool.return_to_pool(dropped)
	_head = (_head - 1 + _CAPACITY) % _CAPACITY
	_ring[_head] = cmd
	_size += 1


## Peek at the front of the queue without removing. Returns null on empty.
## Returns Object — caller treats as Command (RefCounted with `kind` and
## `payload`). Untyped to dodge the class_name resolve race.
func peek() -> Object:
	if _size == 0:
		return null
	return _ring[_head]


## Pop and return the front of the queue. Returns null on empty. Caller is
## responsible for returning the popped Command to the pool when done.
func pop() -> Object:
	if _size == 0:
		return null
	var cmd = _ring[_head]
	_ring[_head] = null
	_head = (_head + 1) % _CAPACITY
	_size -= 1
	return cmd


## Drop all queued Commands and return them to the pool. Used for "right-click
## replace" semantics (Contract §3.5).
func clear() -> void:
	while _size > 0:
		var cmd = _ring[_head]
		_ring[_head] = null
		_head = (_head + 1) % _CAPACITY
		_size -= 1
		if cmd != null:
			CommandPool.return_to_pool(cmd)
	_head = 0


## Number of queued commands.
func size() -> int:
	return _size


func is_empty() -> bool:
	return _size == 0
