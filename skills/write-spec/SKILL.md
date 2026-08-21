---
name: write-spec
description: Write a spec in Speqq for any kind of work, a feature, a bug, an A/B test, or research. Confirm the type first, then let its template drive the body. Get context, confirm the scope, research the area, write, and validate in a loop. Use it when a user wants to spec a feature, write up a bug, plan an A/B test, capture research, write requirements, or turn a scoped idea into a spec.
---

# Write a spec

A spec frames the work before you build it, and stays the record of it afterward. This is one flow for four kinds of work: a feature, a bug, an A/B test, or research. You confirm the type first, and the template for that type drives what you write. Keep every part lean, and keep it to the output: what the work is and does.

## Prerequisites

Confirm each of these before you write. If one is missing, set it up first.

- **Access to the Speqq plugin.** The Speqq spec-kit is installed, so these skills and their hooks are available to you.
- **Access to the Speqq MCP.** You can reach Speqq and you are signed in. If a Speqq action fails because the server is unreachable or you are not authorized, run check-connection first.
- **The work is tracked in the queue.** A queue item names this work, has a one-line description, is set to in progress, and carries a branch name. Create or complete it if any of that is missing.
- **The spec exists and is linked.** A spec for this work exists and is linked to the queue item. Find it in your list of specs and reuse it, or create one with a commit-style title such as `feat: user auth`, then link it to the queue item.

## Steps

Confirm the type, get context, and confirm the scope first. Then steps 4 to 7 are a loop: understand the current state, research, write, and validate. If the spec does not validate, go back to step 4 and refine. Record what you learn and decide in the spec's memory as you go, and keep the spec itself to the output.

1. **Confirm the type.** Ask the user which kind of work this is, then open the matching template. It defines the body you will write.
   - Feature: `templates/feature.md`
   - Bug: `templates/bug.md`
   - A/B test: `templates/abtest.md`
   - Research: `templates/research.md`
2. **Get context.** Understand the product and the user you are working on. Read the product context so you know who you serve and how this work fits.
3. **Confirm the scope.** Before you research, put your open questions to the user, one at a time, and fold in the answers. Do not assume the scope.
4. **Understand the current state.** Read the code and the relevant documentation to learn how this works today and the landscape around it.
5. **Research the area.** Learn the best practices for this, including how other products and domains solve it well.
6. **Write.** Write the body the template defines. Keep each part loose and usable, and keep it to the output, not your notes.
7. **Validate.** Check the spec is complete, accurate, and something you can build from. If it is not, go back to step 4 and refine.

## FYI

- The spec is what the user reads. Keep open questions, decisions, and research notes in the spec's memory, not the spec: they are what you need to remember, not what the user needs exposed. Resolve open questions rather than parking them. Research is the exception when the user actively wants it in the spec, and even then the excessive detail stays in memory.
- The template drives the body. The skill is the same flow for every type; what changes is the template you follow.
- Write to Speqq, never to local files.
- Follow `references/style-guide.md` for the words.
- Keep it loose. Write what the work needs now and let the spec grow as the build proves what it needs.
- Default to the industry standard for product, UX, and technical patterns unless the user asks for different.
- Write one spec at a time. Two writers at once collide and drop content.
