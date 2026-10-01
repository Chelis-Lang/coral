# Coral Agent Contract

Canonical agent instructions for this repository. `CLAUDE.md` is a symlink
to this file so Claude-style and Codex-style entry points do not drift.

## Repo Identity

<!-- shell-local:exclude:begin -->
<!-- ### Pull Request Lifecycle -->
<!-- ## Spec Authority And Design Discipline -->
<!-- ## Change Hygiene -->
<!-- ## Issue Tracking -->
<!-- ## Environment And Tooling -->
<!-- ## Subagents -->
<!-- ## The Chelis-Lang Repositories -->
<!-- ## Pointers -->
<!-- shell-local:exclude:end -->

<!-- BEGIN CHELIS MANAGED BLOCK: agents-inheritance chelis@0.18.12 (sha256:9fca24d7e0aa2b96) -->
# Chelis Agent Contract

Keep this file concise and relevant to every agent working in this repository.
Each added token is read tens of thousands of times. State a rule once, link the
document that owns the detail, and put the explanation in that document, not here.

`CLAUDE.md` is a symlink to this file so Claude-style and Codex-style entry points do
not drift.

## What Chelis Is

Chelis is a functional language for AI research, built for a workflow where a coding
agent is the primary author and a human is the supervisor, and where the programs are
themselves AI systems: models, training loops, search spaces, learned functions. The
bet is that a type system, representation, and compilation model designed around AI
primitives from the start beat ones bolted onto Python or a systems language later. It
is not a general-purpose language, a systems language, a web framework, or a Python
replacement. `spec/00-context.md` and `spec/design/chelis_canonical_reference.md` own
the full statement; their specifics may lag, their intent does not. When a tradeoff
appears, apply these in order:

1. **Unambiguity over ergonomics.** The author is an agent. The friction a human feels
   spelling out every type, effect, dtype, and dimension is not worth a reading the
   compiler has to guess at.
2. **Composition over special cases.** A new capability composes existing primitives
   before it earns a new one.
3. **Inference over annotation.** Where the checker determines something uniquely, the
   author does not repeat it; intermediates carry no ascription.
4. **Machine generation first.** A convenience that exists only for a human typist is
   not a reason to add syntax, a default, or a fallback.
5. **Additive sugar only.** Every surface form desugars to the core; nothing in the
   surface has semantics the core lacks.
6. **Explicit over implicit.** No implicit broadcasting (`expand` only), no implicit
   precision promotion, no implicit currying or partial application, no silent
   narrowing at ingress, no hidden effects. Where intent cannot be determined uniquely,
   the compiler rejects.
7. **Small language, big library.** The compiler knows only the closed RISC primitive
   set and its derived built-ins; everything else is a library. The canonical reference
   §8.5 has the core/standard-library/external-library taxonomy.
8. **Future-proof without over-building.** Decide the rule fully now, implement what
   the phase needs, and never narrow a rule to what a lane implements today.

Two corollaries govern how the compiler itself is changed. Chelis is pre-compatibility
unless a controlling contract says otherwise, so prefer the structural design that
makes a defect class impossible over a smaller-blast-radius patch, a legacy default, a
versionless compatibility fallback, or phase deferral; close the class, not the
instance. And determinism is part of the contract: for fixed program text, compiler
build, target, and declared inputs, every check, evaluation, and build result is a
function of those inputs, and feedback that varies between identical runs is a defect.

## Quality Standards

### Spec-First Development

- Before writing implementation, write test stubs derived from the owning spec.
- Every spec requirement should have a corresponding test before the code exists.
- If the spec says "X is a type error," write the failing test before implementing
  the checker.

### Negative Test Parity

- For every test that checks something works, add the corresponding failure test.
- If you cannot name the failure case, the spec understanding is still weak.

### Do Not Trust Green

- Passing tests prove alignment with the tests, not necessarily with the spec.
- After green CI, check what active requirements still lack tests.
- Audit silent fallbacks, default values, empty error vectors, and `unwrap_or` paths.

## Review And Merge

### Red Team Rounds

Run every round through the [`redteam-exec` skill](agent-skills/redteam-exec/SKILL.md).
It carries the brief shape, the worktree-reuse rules, and the verify mode.

- Red team against the spec, the code, the tests, the examples, and the CLI behavior.
  Execute tests and commands; source inspection is not proof.
- Every pull request, documentation-only work included, gets at least one round before
  merge. A round is the whole live back-and-forth between one reviewer and the author,
  not a single review pass:
  1. A fresh local subagent reviews the exact head from an inline brief and reports
     its findings.
  2. The reviewer stays alive. The author repairs the findings in the worktree.
  3. The author hands the repair back, and the same reviewer verifies it and looks for
     similar issues the repair may have missed or introduced.
  4. Any further finding goes back to the author, and steps 2 and 3 repeat.
  5. The round ends only when that reviewer states it is satisfied.
  A reviewer that has reported is not finished; it is waiting for the fix. Ending the
  loop after the first report, or verifying a repair with a different reviewer, is not
  a round.
- A pull request gets at most three fresh rounds; a fourth needs the user's explicit
  approval. A prose-only pull request gets one, and a second needs the same approval.
  The pull request's round record is the counter. Verification by the standing reviewer
  does not count; the end-of-pull-request round does.
- A finding is in scope only when the pull request introduces it, worsens it, or claims
  to correct it. Discovery during review does not bring a pre-existing defect into scope.
- A confirmed in-scope P0 or P1 merits a fresh round after the current round finishes,
  within the cap. Unmigrated assertions, old comments, and minor documentation drift do
  not. A rebase does not by itself merit a round: send a hand-resolved intersection that
  stays within files the standing reviewer already read to that reviewer for focused
  verification, and use a fresh round only when the rebase introduces a new mechanism or
  touches files that reviewer did not read. A targeted review of substantial rebase
  overlap needs no permission and never counts toward the cap.
- For documentation and design reviews, severity follows contract impact. A wrong
  normative rule, or a plan that cannot close a named in-scope deliverable, is P0 or P1.
  A design document that misdescribes current `main`, or exposes a sequencing seam while
  the contract stays achievable, is P2 or P3 and is recorded as residual work, never
  promoted to a merge blocker. Wording, line-level accuracy of the pull request body,
  staleness against a sibling pull request's moving head, and anything whose fix would
  add text without a necessity sentence are out of scope.
- State a pull request's claim at the granularity its oracle proves. An unbounded
  universal claim invites sampling in every round and can never be closed.
- A finding class is the defect category, not its file, line, or wording instance.
  Every round record names the class of each finding. When two consecutive rounds
  report the same class, or replace a repaired finding with a different class, stop
  patching witnesses: change the representation, the oracle, the claim, or the brief
  before running another round.
- Repairs may correct, remove, or narrow the pull request's content. They must not add
  design scope, mechanisms, inventories, or promises merely to absorb a finding. When a
  correction would need that, reduce the claim and track the rest outside the pull
  request.
- Freshness is a property of the reviewer's context, not the filesystem. Hand a
  reviewer an existing worktree and its warm target only when it is at the exact review
  head, has a known clean baseline, and has no concurrent writer, and paste the output of
  `.venv/bin/python scripts/worktree_status.py` into the brief as the evidence. Unknown
  or not-clean means wait, and free is the probe's best answer rather than a proof: a
  run that takes no lease, `--fast` among them, is caught only by a scan of the
  processes it spawned. A reviewer whose probes mutate tracked source gets its own
  worktree, and you never edit a worktree a reviewer is reading.
- Before spawning a fresh round, retire only your own stale or failed subagent handles;
  a standing reviewer awaiting a fix is neither. If a spawn routes to remote
  infrastructure, errors, or comes back broken, retire it and retry until you have a
  working fresh local subagent, or state that red-team validation is blocked.

## Writing Chelis Source

Load the [`example-corpus` skill](agent-skills/example-corpus/SKILL.md) before writing
any `.ch`; it carries the Surf style rules, the parse-breaking spellings, and the Deep
AST contract. `spec/02-surf-syntax.md` §0.1 is the authority.

- `chelis build`, `check`, `validate`, and `eval --file` run `chelis fmt --check` and the
  blocking `chelis lint` rules before the front end; style failures block the build.
  `--allow-style-violations` is for emergency local builds only, never CI, and
  `CHELIS_STYLE_GATE_DISABLE=1` is reserved for the integration-test corpus. Run
  `chelis fmt --inplace <file>` and `chelis lint --check` before pushing.
- Type system: no implicit precision promotion, named tensor dimensions match by name,
  no implicit broadcasting (explicit `expand` only), integer literals default to `i32`
  and float literals to `f32`.
- `chelis build` emits C, a header, runtime artifacts, and compile flags; `--target hip`
  emits host code with embedded kernel strings. Neither invokes the native compiler.

<!-- END CHELIS MANAGED BLOCK: agents-inheritance -->

- Coral is a downstream **shell repo** for the
  [Chelis](https://github.com/Chelis-Lang/chelis) language, scoped to
  typed dataframes and tabular transformations.
- Intent: a Chelis program should be able to load tabular data, filter,
  sort, group, join, reshape, and window it, and write it back out, with
  typed column access and numeric columns stored as Chelis tensors so they
  flow into the rest of a tensor program. [`spec/scope.md`](spec/scope.md)
  states the full intent and what is deliberately deferred.
- Upstream of truth: `Chelis-Lang/chelis`. The retained sections of its
  `AGENTS.md` apply here with the shell-owned rules below. Paths in retained
  upstream text that do not exist in Coral refer to the pinned Chelis source.
  The selector span above removes compiler-repository procedures; `chelis
  reef conform sync` keeps the retained instructions current.

## Review and Merge

Use [`agent-skills/redteam-exec/SKILL.md`](agent-skills/redteam-exec/SKILL.md)
for an independent review before merging a PR. When its worktree status
probe is needed, run the pinned Chelis source's
`scripts/worktree_status.py --path <Coral worktree>` with this worktree's
uv Python 3.11 interpreter. Keep a reviewer's worktree isolated from a
concurrent writer or build. Before a squash merge, inspect the pushed head,
applicable hosted CI, review result, and prospective merge tree. Coral's
Pin Bump Checklist below owns its release validation.

## Toolchain Policy

- Coral should track the latest **published and validation-clean**
  Chelis release by default. Treat stale pins as drift, not as a reason
  to stay on an older compiler.
- `reef.toml` pins the currently validated published compiler exactly, and
  the published Nautilus release built for that compiler. Dependency hashes
  come from the published payload, never a guessed version or a locally
  repacked artifact.
- If the latest published Chelis release fails Coral validation, document
  the blocker in `docs/UPSTREAM_BUGS.md` and pin the newest known-good
  release until the blocker is resolved.
- Validate against the **installed published** toolchain, not a from-source
  build: `chelisup install <version>`, then `chelis +<version> ...` or
  `$CHELIS_HOME/toolchains/<version>/bin/chelis`. The shim also resolves
  from `reef.toml`'s compiler pin, as CI does.
- Bumps cascade in dependency order (Nautilus first, then Coral), because
  Reef requires every dependency to declare the same compiler pin. Resolve
  the exact published dependency with `chelis reef install --from-github
  Chelis-Lang/nautilus@v<version>`, the same path CI uses, and run the full
  Pin Bump Checklist.
- Do not vendor or build the Chelis compiler from source inside this
  repo. Consume the released tarball from the private
  `Chelis-Lang/chelis` releases. CI authenticates via the repo secret
  `CHELIS_RELEASE_TOKEN`, which must hold a PAT with `contents: read`
  on `Chelis-Lang/chelis`. Rotate with
  `gh secret set CHELIS_RELEASE_TOKEN --repo Chelis-Lang/coral`.
- Native test CI uses the released compiler's node-local concurrency:
  `chelis test tests/ --jobs auto`. Keep `--jobs 1` as the local serial
  debugging fallback; do not reintroduce per-file matrix sharding unless
  a documented semantic reason appears.

## Pin Bump Checklist

A pin bump is a **de-narrowing event**, not a version edit. Complete all
of these steps in one change set and land the bump through a pull
request, never by editing the pin directly on `main`.

1. Run `chelis reef conform bump <version>`. Confirm that `reef.toml`
   and every toolchain-installing workflow's `CHELIS_TAG` /
   `CHELIS_VERSION` pair agree, and that the offline pin-consistency
   guard passes. Bump order: `nautilus` (this shell's reef dependency)
   must reach the target pin **first**; flip the `nautilus` dep and
   `NAUTILUS_TAG` to its matching release in the same change set.
2. Run the blocked-probe suite when `tests_blocked/` is populated. A
   **FIX-detected** probe means the upstream limitation is gone: execute
   its de-narrowing instructions, promote it to a real test, remove the
   workaround, and archive the corresponding `UPSTREAM_BUGS` entry. A
   **DRIFTED** diagnostic must be investigated before it is re-cited.
3. Run `chelis reef conform audit --explain` and triage every
   closed-upstream issue still cited by a downstream workaround. Retire
   the workaround or cite the live residue issue; never carry it
   silently.
4. Re-probe every `docs/UPSTREAM_BUGS.md` entry due under its section
   cadence, **per verb and per surface**. A changelog claim is not
   verification. Re-probe manually when a reproducer cannot be expressed
   as a probe (e.g. the Parquet runtime-symbol check, the bare-build
   lane via `scripts/repro_multimodule_bare_build.py`).
5. Refresh `docs/CHELIS_SURFACE.md`: pinned and upstream versions plus
   every `@pin` / `@upstream` marker.
6. Reclassify `UPSTREAM_BUGS` entries from the re-probe results: archive
   fixed behavior, retain live limitations under Tracking or Actively
   blocking, and record any remaining residue and its next trigger.
7. Run the complete local gate before pushing: per-file
   `chelis fmt --check`, `chelis lint --check .`, `chelis reef build`,
   `chelis test tests/ --jobs auto`, `chelis test tests_neg/ --expect
   neg`, the strict pandas parity gate through its isolated Python
   environment (`uv run --project parity python parity/run_parity.py
   --strict`), `scripts/run_static_checks.py`,
   `scripts/run_skill_checks.py`, `scripts/validate_book_examples.py`,
   and `scripts/repro_multimodule_bare_build.py` (all targets). Finish
   with `chelis reef conform audit` and
   `chelis reef conform bump-check --base origin/main`.

Record the per-surface re-probe results and any expected unlocks in the bump
pull request description and a `CHANGELOG.md` entry. Do not check in
per-version migration documents: the repository describes the current pin,
and history lives in `CHANGELOG.md`, pull requests, and git.

## Scope and Acceptance

[`spec/scope.md`](spec/scope.md) owns Coral's intent, architecture as built,
acceptance rules, known limitations, and dated deferrals. `SKILL.md` §5 is the
public API inventory. [`CONTRIBUTING.md`](CONTRIBUTING.md) lists the local gate
commands. The original Phase 3k design plan lives in the Chelis monorepo
(`spec/design/chelis_phase3_plan.md` §3k); `spec/scope.md` records where Coral
as built departs from it.

## Upstream Chelis Bugs

Upstream limitations are tracked in
[`docs/UPSTREAM_BUGS.md`](docs/UPSTREAM_BUGS.md), with executable reproducers
under `tests_blocked/` where the harness can express them and Python probes
under `scripts/` where it cannot. Cite every narrowing by issue number at its
site, or by a dated deferral in `spec/scope.md`; never describe a limitation by
prose name alone.

## Shared Local Skills

Project-local skills live in `agent-skills/`. `.claude/skills` and
`.codex/skills` are symlinks to that directory so both tool surfaces
load the same skill library. `.claude/commands/` and `.codex/commands/`
mirror each other. The complete shared set (`redteam-exec`, `spec-sync`,
`phase-gate`, `backend-numerics`, `example-corpus`, `cli-surface`,
`packaging-install`, and `issue-resolution`) is toolchain-owned material,
regenerated by `chelis reef conform sync`, and stamped in
`agent-skills/UPSTREAM.toml`; do not edit its managed content as a copied
fork. Keep the `red-team` alias wired to `redteam-exec`.

## Scaffolding Drift Rule

All Chelis shell repos share the same scaffolding shape by design. Any
structural change to this repo (layout, CI workflow, agent surface,
reef manifest format) should be mirrored into the other shell repos in
the same change set, or explicitly flagged as a per-repo divergence
with a recorded reason.
