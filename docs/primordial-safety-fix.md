# Primordial resolver and AA safety fix

Base branch: main. Review branch: fix/primordial-resolver-aa-audit.
Reviewed uploaded Lua SHA-256: 8c17bbe4dd96db9951f7c3bd22ab52e91d5908e40dc81525f1df2ec9541f076e.

## Changes

1. Bound defensive/lag-break attribution by fire time plus RTT, not arbitrary result delay.
2. Preserve the original key, candidate and model metadata for a held resolver value.
3. Fix the Lua nil-ternary expression that mislabeled fresh values as held.
4. Credit held-shot feedback to the original decision context.
5. Allow at most one eligible bandit update per incoming-shot snapshot; damage-event statistics remain separate.
6. Suppress delayed near-miss reactions after confirmed hurt/evade, death, disable, attacker replacement, local-player replacement, time rewind or expiry.

No new offsets, signatures or Primordial API calls are introduced. Resolver angle priors, AA presets, body-aim defaults and fake ping are not retuned without evidence.

## Validation and safe application

The patcher tokenizes Lua while ignoring comments and whitespace. It requires the exact reviewed semantic source hash, checks each edit has one match, rejects overlaps and verifies the final semantic hash. It preserves unrelated repository source and comments. An already patched source is a no-op. Any other source fails closed.

Local checks completed: patch construction, Python syntax, idempotence, comment preservation and rejection of unreviewed source. Local LuaJIT execution was unavailable; no game performance or hit-rate improvement is claimed.

The branch-scoped GitHub Actions workflow installs lupa 2.6, applies the patch on its runner, compiles the full Lua through LuaJIT and runs the new focused tests plus existing Primordial regressions and advanced harness. It commits only specter_primordial.lua to the review branch after all tests succeed. It does not merge a PR or publish cloud. A failed check leaves the source uncommitted and must be investigated before merge.

Oct 16-17 logs are observational baseline only, not counterfactual proof that a new angle would hit or evade.
