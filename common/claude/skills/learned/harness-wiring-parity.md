# Test Harness / Simulator Must Replicate Entry-Point Wiring

**Extracted:** 2026-05-26
**Context:** Projects where the production entry point does critical setup at import/startup time (DI wiring, router/feature-flag enablement, dependency injection, handler registration) — and there's a separate dev simulator or test harness that constructs its own app.

## Problem
A dev simulator (or alternate harness) imports the same modules and managers as production but **does not replicate the entry point's import-time wiring**. It then silently exercises a *different* code path than prod — e.g. the new/feature-flagged path is never enabled, so the harness runs the legacy fallback. Manual testing in the harness gives **false-green confidence**: the thing you changed isn't even reached.

Real case: `whatsapp_pizza_bot.py` wired the FSM router at import time (`configure_nlu`, `configure_menu_deps`, `configure_summary_builder`, `configure_payment_deps`, `register_handoff_dispatch(...)`, and a `_enable_promoted_fsm_states()` that flips on `FSM_ENABLED_STATES`). `simulator.py` constructed the managers but wired **none** of that — so `FSM_ENABLED_STATES` stayed empty, `_dispatch_via_fsm` was a no-op, and every turn fell to the legacy handler. None of the FSM-native fixes would have been testable there.

## Solution
1. When auditing a change, **check whether the harness/simulator wires the same setup as the prod entry point.** Grep the harness for the same `configure_*` / `register_*` / `enable_*` calls the prod entry point makes.
2. If wiring is duplicated, make the harness mirror it (or extract a shared `wire_app(...)` both call). Account for differences in identity/lookup (e.g. prod keys instances by `chat_id`, the simulator by bare `phone` → strip suffix in the lookup).
3. Watch for **secondary parity gaps** beyond enablement: e.g. poll/event IDs. The simulator's mock didn't pass `poll_id` through to the handler, so FSM poll-vote lookups (keyed by `poll_id` in `fsm_polls`) missed and fell back to legacy. Track and forward the same identifiers the real transport carries.
4. Add a startup log line in the harness confirming the wiring (`"✅ harness FSM router wired (NLU=on)"`) so a missing-wiring regression is visible at a glance.

## Example
```python
# Prod entrypoint (import-time): wires router, deps, handoffs, enables states.
# Harness MUST mirror it, against its own instance lookup:
def _sim_customer_for_chat(chat_id):
    return user_instances.get((chat_id or "").replace('@c.us', ''))  # sim keys by bare phone

router.configure_default_toolbox(inventory)
router.configure_nlu(nlu_client)
router.configure_menu_deps(inventory, categories)
pm_actions.configure_payment_deps(settings, create_order_fn=_sim_create_order)
for target, fn in HANDOFFS: router.register_handoff_dispatch(target, fn)
for st in PROMOTED_STATES: router.enable_state(st)

# And forward transport identifiers the framework needs:
poll_id = mock_transport.latest_poll_id(chat_id)
user.handle_poll_response(chat_id, option, session, ai, sessions, poll_id=poll_id)
```

## When to Use
- About to manually test a change in a simulator/sandbox/harness that isn't the real entry point.
- A change "works in tests" or "works in the simulator" but you suspect the new path isn't actually engaged.
- Stubbed/mock tests pass but you're unsure the production wiring (DI, flags, handler registration) is even active in that harness.
- Building or reviewing a second runner (CLI, sim, e2e app) for a service whose entry point does heavy import-time setup.
