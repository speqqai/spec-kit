---
name: spec-research
description: >-
  Get up to speed on a piece of work before specifying it — reads PRODUCT.md,
  the related specs already in the workspace, the code that exists today, and
  the queue, then reports the current state, what has already been decided, and
  the open questions. Use before spec-product or spec-eng, when a user asks what
  exists today, how something works now, whether this has been specced before,
  or to research an area. Appends what it finds worth keeping to the spec's
  MEMORY.md as it goes, so the next agent inherits the findings instead of
  re-deriving them.
---

# spec-research

Answers the question every spec starts with: **what is true today, and what has
already been decided?**

Written before this, a spec re-litigates settled decisions, re-specifies things
that already ship, and invents constraints the codebase does not have. The
research is not preamble — it is what makes the spec correct.

The only thing this skill writes is snippets to the spec's memory — see
**Record what matters, as you find it** below. It writes no spec content, and
nothing at all to the user's machine.

## Preflight

`list_workspaces` first — one workspace, use it; several, ask. You also need
`spec_orient`, `spec_read`, `spec_list`, `queue_read`, `spec_memory_append`,
and your own file tools.

**Resolve the spec before reading anything.** In order: a queue item the user
picked, a spec they named, or the current git branch via `spec_orient`. If none
answers, **run `spec-init` first** — the findings have to land somewhere, and a
spec is what gives them a memory to land in.

## What to read, in this order

1. **What the product is.** `spec_orient` returns a `product_file` pointer when
   the workspace has a PRODUCT.md; `spec_read` it. What the product is, who it
   is for, what it is going after, and **what must never break**. That last one
   is a constraint on everything you are about to propose, and nothing in the
   code states it.
2. **What has already been specified.** `spec_list` the workspace and read the
   specs that touch this area. Two things matter: decisions already settled
   (do not re-open them without saying you are), and requirements that already
   cover part of what the user is asking for. An existing spec is a reason to
   extend rather than start over.
3. **What is already queued.** `queue_read` for work in flight on the same
   area. Read it bounded — the queue can be large, and pulling all of it wastes
   the context this skill exists to fill. Work already queued is a collision
   worth surfacing before anything is written.
4. **What the code actually does.** Read the working tree with your own file
   tools — read, grep, glob. The checkout is the source of truth: not an
   indexed graph, not your memory of a similar codebase, not the spec's
   description of what the code should do. Find the real surfaces, the existing
   patterns for this kind of change, and the conventions the repo enforces.
5. **What the repo forbids.** Its agent-instruction file, contributing guide,
   style rules, and decision records. These are gates on the design, not
   background reading — a proposal that violates one is not a proposal.

## Record what matters, as you find it

Research is the cheapest thing to lose and the most expensive to repeat. When
you find something the next agent would want to know, `spec_memory_append` it to
the spec **at the moment you find it** — not in a batch at the end, which is the
batch that never gets written when a session ends early.

Record a finding when it changes what someone would build:

- **A surprise.** The code does not do what the docs, the spec, or the name
  claims. *Found the type exclusion is applied in SQL, not in the client — the
  UI cannot reveal what the server never sends.*
- **A constraint you discovered.** A repo rule or product invariant that any
  design has to satisfy. *Found the collab server is the single write authority
  — REST writes to document content return 409 by design.*
- **Something that already exists.** Part of the request already ships, or is
  specced, or is queued. *Found the append primitive already exists; only the
  read path is missing.*
- **A decision already settled.** So nobody re-opens it by accident.

Do NOT record a reading list. "Read the panel component" is not a finding; it is
a thing you did. If the line does not change what someone would build, leave it
out — a log padded with activity is one nobody reads.

Write each as one line, past tense, leading with the verb — the same form
`spec-snippet` describes. The server stamps the time.

**If the spec has no memory yet, the first append creates it** — there is
nothing to set up.

**If no spec exists at all, set one up before researching.** Findings need
somewhere to land, and research done first is research that has to be redone.
Say so and run `spec-init`: it creates the spec shell, files the queue item,
links them, and flips the item to `in_progress`. Then research against that
spec, recording as you go. Do not research first and file afterwards — a session
that ends in between loses everything it learned.

## What to report

Short, and in this shape:

- **How it works today** — the real path through the real code, with file paths.
  Someone should be able to open what you name and see it.
- **What is already decided** — from PRODUCT.md, existing specs, and decision
  records, each with where it came from.
- **What already exists of this request** — the part that ships, the part that
  is specced but unbuilt, the part that is queued.
- **What is genuinely open** — the questions the code and the specs do not
  answer. These become the clarifying questions spec-product asks.
- **What constrains the answer** — repo rules and product invariants that any
  design has to satisfy.

Then stop. Do not propose the design, and do not start writing the spec —
`spec-product` and `spec-eng` own those, and they run their own grounding.

## Worth being careful about

- **Cite what you read.** Every claim about current behaviour names a file. A
  claim you cannot point at is a guess, and a guess in this report becomes a
  requirement three skills later.
- **Separate what you verified from what you inferred.** Say which is which.
- **Do not fill gaps with plausible answers.** "The code does not say" is a
  finding — it is often the most useful line in the report.
- **Bound what you pull.** Reading everything is not research; it is how the
  context runs out before the spec gets written.
- **Append as you go, not at the end.** A session that ends before its final
  report still leaves its findings behind if they were recorded when found.
