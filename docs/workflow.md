# Workflow

Spec-Kit is spec-driven development with one fundamental difference from file-based kits: the spec is a living document in Speqq, not a `specs/` directory. Every skill writes over MCP, the spec's table rows are the live progress ledger, and there is zero local state — no tasks file, no pointer file, no progress markdown. The only things ever written to your machine are the git branches and commits that *are* the implementation.

The six authoring skills — the four discipline skills plus `spec-fix` and `spec-converge` — share one loop: **ground → brainstorm → write**. Ground reads the real working tree and the workspace context; brainstorm settles options and open questions with you; write lands clean, final, present-tense prose in Speqq — with a user checkpoint before each section lands. The two execution skills keep the first two beats and change the third: `spec-queue` grounds, then proposes its create/skip table before filing anything; `spec-implement` grounds, then reviews the run with you before it touches code. Working notes never enter the spec.

## Two starting states

**Greenfield idea.** You have a feature in your head. Start with `spec-product`: it grounds in your repo, asks up to five targeted clarifying questions, and creates the feature spec — a commit-form title (`feat: user auth`, `feat(scope): branch links`), an Overview page, and a Requirements table of testable capability statements with Given/When/Then acceptance-criteria child rows. From there the other discipline skills add their tabs.

**Picking up queued work.** A plan already exists and its work is filed in the Speqq queue. Start with `spec-implement`: point it at a queue item (or just start it on the feature branch) and it resolves the spec, reads the Implementation plan, and executes it.

For bugs, `spec-fix` is its own entry point: it reproduces and locates the failure, confirms the root cause with evidence, then writes a lean fix spec — Overview / Root cause / Fix / Validation — as `fix(scope): <name>`.

## One spec, four disciplines

The discipline skills compose onto a single feature spec — each owns its tabs, none overwrites another's:

| Skill | Owns | Tab type |
| --- | --- | --- |
| `spec-product` | Overview, Requirements | page + table |
| `spec-ux` | Design | page |
| `spec-eng` | System design, Implementation plan | pages |
| `spec-qa` | Test plan | page |

Order is flexible. `spec-product` normally creates the spec, but any discipline skill creates it if it runs first — and every skill locates an existing spec by title and reuses it rather than duplicating. The traceability spine is the **requirement title**: spec-ux heads each design section with the exact requirement title, spec-eng maps every requirement to components in its traceability table and every plan step to the requirement it delivers, and spec-qa's test cases each name the requirement they verify, closing with a coverage map. One source of truth, four views onto it.

## The execution loop

Once the plan exists, the loop is **queue → implement → converge**, repeated until the spec and the code agree.

**`spec-queue`** files the Implementation plan's steps into the Speqq workspace queue — one item per step, commit-form titles, the spec id embedded for traceability, priorities mapped to the workspace's labels. It dedups against the existing queue first and checkpoints the full create/skip table with you before filing anything, so re-running it after the plan changes is safe and idempotent.

**`spec-implement`** executes the plan against the real repo. It creates the feature branch derived from the spec title (`feat: user auth` → `feat/user-auth`), links the branch onto the rows it delivers, marks the queue item `in_progress`, then works milestone by milestone. For every step it flips the row to `in_progress` *before* writing code, makes the narrowest change that satisfies the step, runs the repo's own validation gates (never invented ones — a red gate blocks the step), commits, and flips the row to `done` with the commit recorded before moving on. The spec is the progress dashboard: anyone watching it in Speqq sees rows flip live as work lands.

**`spec-converge`** reconciles reality against intent. It reads the Requirements and Implementation plan, inspects the present working tree (not git history), and gives every requirement, criterion, and step an evidence-backed verdict: done, partially met, or unmet. Genuinely-done rows flip to `done`; the remaining gap is appended as new concrete plan steps — deduped against existing steps, never rewriting, renumbering, or deleting anything. If the code already satisfies everything, it writes nothing and reports **converged**. Otherwise, `spec-implement` picks up the appended steps and the loop continues.

## Setting work up, and getting up to speed

**`spec-init`** stands up a new piece of work in one act: the spec shell, the matching queue item, the link between them, the priority, and the flip to `in_progress`. It is one skill rather than four steps because doing them separately is how one gets forgotten — a spec with no queue item is invisible to whoever picks work up next, and a queue item with no spec is a title with nowhere to write. It creates scaffolding only; the content is written by the discipline skills. (Assignment is the one thing it cannot do: no MCP tool sets an assignee today, so it says so rather than claiming otherwise.)

**`spec-research`** answers the question every spec starts with: what is true today, and what has already been decided? It reads PRODUCT.md, the specs already in the workspace, the queue, the actual working tree, and the repo's own rules — then reports how things work today with file paths, what is already decided, what already exists of the request, and what is genuinely open. Written without this, a spec re-litigates settled decisions and invents constraints the codebase does not have.

If no spec exists yet, it runs `spec-init` first rather than researching into thin air — findings need a memory to land in, and research done before the spec exists is research that has to be redone.

It also records as it goes. When research turns up something that changes what someone would build — the code not doing what its name claims, a constraint nobody wrote down, a part of the request that already ships — it appends that to the spec's memory at the moment it finds it. Findings are the cheapest thing to lose and the most expensive to repeat, and a batch written at the end is the batch that never gets written when a session stops early.

## What the agent carries between sessions

A spec keeps a **MEMORY.md**: an append-only log of what happened while it was built. One line per entry, timestamp first, oldest at the top — no categories and no schema, just the agent's own sentence about what just happened. It exists because a context window ends, sometimes deliberately and sometimes not, and anything not recorded is lost with it.

Four skills work the session around it:

- **`spec-start`** opens work on a spec that has not been worked yet, recording what the run is going after. It refuses a spec that already has snippets and points at `spec-resume` — a beginning written into the middle of a log misleads every later reader.
- **`spec-pause`** closes a session: one line covering what landed, what did not and why, and what is next, plus honest row statuses. Write it even when the session achieved nothing — *"spent the session trying X; it does not work because Y"* is a full session's value preserved.
- **`spec-snippet`** appends one line on demand, whenever there is something worth keeping.
- **`spec-resume`** reads the memory *before* the plan and reports where the work stopped and what was already abandoned. Not repeating a dead end is most of its value.

The rule underneath all four: **when an agent learns something the next one would want to know, it appends a line.** An approach tried and dropped, a decision between options, a surprise in the code, a gate that failed for a reason worth remembering. Not every step — a step that went exactly as planned is already recorded by the plan and the commit.

The log is append-only in the strict sense. `spec_memory_append` is the only way in, it stamps the time itself, existing lines are never edited, and the generic markdown write tools refuse a memory outright. That is what makes it trustworthy under interruption.

**PRODUCT.md** is the other file, one per workspace: what the product is, who it is for, what it is going after, and what must never break. It is the answer to *what is this product* that reading the code cannot produce. `spec_orient` returns its id; `spec_read` fetches it. Anyone with workspace access can edit it, and so can an agent — edits apply as patches, so an agent writes around a person's words rather than over them.

## Resolving the active spec with zero local state

There is no state file telling the agent what it's working on. `spec-implement`, `spec-converge`, and `spec-queue` all resolve the active spec from Speqq-side data plus the checkout itself, in a fixed order, stopping at the first rung that answers:

1. **A queue item you picked** — its linked spec is the spec.
2. **A spec you name** — matched against spec titles.
3. **The current git branch** — matched against the branch values recorded on spec rows (an interim bounded scan today, pending a direct by-branch lookup).
4. **Specs with status `building`** — exactly one: confirm it; several: ask.
5. **Otherwise ask** — a short workspace overview, and you choose.

This is why any session, on any machine, can pick up the work: the branch and the spec's own rows carry the state.

## End-to-end example

A walkthrough of one feature, "branch links" — connecting a table row to a GitHub branch and showing its live status.

**Idea → spec.** You say "spec a feature that links table rows to GitHub branches." `spec-product` reads the repo, pulls the workspace's personas from product context, and asks a few sharp questions — one branch per row or many? live status or stored snapshot? who can change a link? You pick: one branch, live status, editors and admins only. It creates `feat: branch links` with an Overview and three requirements — *User can link a table row to a GitHub branch*, *A linked row shows its branch live status*, *Only editors and admins can change a row branch* — each with Given/When/Then children covering the happy path plus invalid, permission-denied, empty, and error edges. You approve each section before it lands.

**Design.** `spec-ux` grounds in the repo's actual design system — the real table-cell, badge, skeleton, and tooltip primitives, with file paths — and adds a Design tab: one section per user-facing requirement, each covering the screen, all four data states (loading, empty, error, success), interactions, and responsive behavior, with a mermaid flow for the linking journey. No invented components, no placeholder mockup URLs.

**System design and plan.** `spec-eng` reads the stack, storage layer, and permission model from the code, settles the open decisions with you, and adds two tabs: a System design (architecture overview with a mermaid component diagram, data model in the repo's real storage terms, key flows as sequence diagrams, failure modes, and a table tracing every requirement to the components that satisfy it) and an Implementation plan — one milestone per requirement in priority order, each step carrying Changes / Surfaces / Depends on / Done when.

**Test plan.** `spec-qa` reads what the repo can actually run — its real test runner, layout, and commands — and adds a Test plan tab: enumerated TC cases, each tracing to a requirement by its verbatim title, typed unit / integration / end-to-end / manual, and labeled automated only when the repo has a proven harness for it. A coverage map closes the tab: every requirement → its case IDs.

**Queue and implement.** `spec-queue` files the plan's steps into the workspace queue — deduped, prioritized, spec id embedded. You pick the first item; `spec-implement` resolves the spec from it, creates `feat/branch-links`, links the branch onto the rows, and works the plan. In Speqq, the Requirements rows flip `in_progress` as each step starts and `done` — commit recorded — as each lands, gates green throughout. Anyone watching the spec sees the run without asking for a status update.

**Converge.** After the run (or after anyone touches the code outside it), `spec-converge` checks every requirement, criterion, and step against the working tree. Two requirements verify done; the permission gate turns out to cover the endpoint but not the picker visibility — that gap is appended as a new concrete step, and `spec-implement` finishes it. The next converge pass reports **converged**, and the feature is done with the spec and the code in agreement.

## Coming soon

Session context injection already ships: the `spec-setup` skill carries session hooks for Claude Code and Codex CLI that inject connection status, workspace orientation, and active work at session start — see [Session hooks](hooks.md). On the roadmap: enforced status sync, phase auto-commit, and branch-guard hooks, plus one-install plugins for Claude Code and Codex that bundle the skills with the Speqq MCP connection.
