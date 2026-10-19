# Primordial safety fix: application retry

The previous full-source fingerprint check rejected the repository copy. PR 173 merged tooling only; no runtime Lua fix was included.

## Targeted application

The new entry point is tools/apply_primordial_reviewed_edits.py. It reuses the six reviewed edits and Lua tokenizer from primordial_safety_patch.py, but validates each target region rather than requiring an identical whole-file fingerprint.

Every edit must have exactly one unchanged original fragment or exactly one already-patched fragment. Duplicate, altered, mixed or overlapping target regions are rejected. Every final replacement is checked again. Source outside the six edited spans is preserved verbatim. Existing patched fragments are a no-op.

The corrections are unchanged: bounded defensive-event attribution; original held-decision ownership; correct fresh/held status; feedback attribution to the held hypothesis; one eligible AA learning update per incoming snapshot; stale/hurt near-miss callback guards. No AA presets, resolver priors, fake-ping settings or FFI layouts are retuned.

## Validation

Local Python checks passed for six edits, repeat application, unrelated-source preservation, partial application, duplicate rejection and altered-target rejection. Local LuaJIT tests remain unavailable; GitHub must run the focused and existing regression suites.

On the review branch, the workflow commits specter_primordial.lua only after all checks succeed. On internal PRs into main, it additionally requires that applying the reviewed corrections produces no uncommitted Lua diff: a tooling-only PR cannot pass as a runtime fix. The cloud branch and Discord bot are not modified.

Before merge, inspect the actual Lua diff and green PR checks. A new Discord build is expected only after the Lua content actually changes on main; no empty version bump or duplicate-upload bypass is used. Discord delivery itself has not been verified here.
