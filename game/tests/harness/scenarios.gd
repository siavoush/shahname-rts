##
## Scenarios — pre-defined match setups for MatchHarness.
##
## Per docs/TESTING_CONTRACT.md §3.1: "scenario is a StringName key into a
## dictionary of pre-defined setups. Adding a new scenario = adding one entry."
##
## Each entry in CATALOG is a Dictionary of initial state overrides consumed by
## MatchHarness._setup(). Unset keys keep the balance.tres starting values
## that ResourceSystem.reset() / FarrSystem.reset() load (150 coin, 50 grain,
## Farr 50.0 as of this writing — balance.tres is the SSOT). Scenarios that
## need harness API calls (farr override) embed the override value under a
## reserved key ("farr").
##
## Adding a scenario: append one entry to CATALOG. No other file changes needed.

# No class_name — avoid the global registry race (ARCHITECTURE.md §6 v0.4.0).
# MatchHarness preloads this file directly via ScenariosScript.

## Scenario catalog. All fields are optional; unset keys keep balance.tres
## starting values (loaded by the autoload reset() chain in MatchHarness._setup).
## Reserved keys:
##   farr         float  — override Farr starting value (default: balance.tres)
##   coin_iran    int    — starting coin for Iran  (default: balance.tres)
##   grain_iran   int    — starting grain for Iran (default: balance.tres)
##   coin_turan   int    — starting coin for Turan (default: balance.tres)
##   grain_turan  int    — starting grain for Turan (default: balance.tres)
const CATALOG: Dictionary = {

	## Blank slate. Default resources, default Farr (50.0 from balance.tres).
	## Use for tests that set up their own state via harness helpers.
	&"empty": {},

	## Both teams start resource-starved. Tests paths where workers can't
	## produce and buildings can't be queued without injecting resources first.
	&"starved": {
		"coin_iran": 0,
		"grain_iran": 0,
		"coin_turan": 0,
		"grain_turan": 0,
	},

	## Farr close to the Kaveh trigger threshold (15.0). Tests the grace-period
	## countdown and player response window without running thousands of ticks.
	&"kaveh_edge": {
		"farr": 16.0,
	},

	## Farr below the Kaveh trigger threshold — event fires on next grace-tick.
	## Use with advance_ticks to confirm the trigger behavior.
	&"kaveh_triggered": {
		"farr": 14.0,
	},

	## Flush economy. Both teams have abundant coin/grain so resource cost is
	## never the limiting factor. Isolates production and combat logic.
	&"rich": {
		"coin_iran": 1000,
		"grain_iran": 1000,
		"coin_turan": 1000,
		"grain_turan": 1000,
	},

	## Placeholder for Phase 2 combat tests. Identical to "empty" at Phase 0 —
	## unit/building scenes don't exist yet. Listed in CATALOG so the
	## determinism regression test (Sim Contract §6.2) can reference
	## &"basic_combat" without a missing-key error.
	&"basic_combat": {},

}
