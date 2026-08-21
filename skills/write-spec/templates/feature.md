# Feature spec template

A feature spec frames the problem before the solution, then says what the feature does and how you will prove it. Cover the parts the work needs: a real feature covers them all, a trivial change can fold or skip the product-framing parts and say which. Keep every part to a few plain sentences or a short list, not walls. Follow `../references/style-guide.md` for the writing.

## Overview (page tab)

Write these parts in order. Each is short.

1. **Objective.** The outcome this delivers, in one line. The what and the why, not the how.
2. **User.** Who it is for, the role or persona. Name them.
3. **Goal and problem.** What the user is trying to do, and the problem they hit today.
4. **Interfaces.** Where this lives, the surfaces it touches: the screens, the API, the CLI.
5. **Core user journeys.** The key flows start to finish, as short numbered steps. The main path and the edges that matter.
6. **Industry standard.** How the category solves this well, the pattern that sets the bar. This is the target unless there is a reason to differ.
7. **Current state.** What the product does today for this. Not supported, or supported but a poor experience, and why. This is the delta the feature closes.
8. **Architecture.** How the feature fits the system: the components, the data model, the contracts, the failure modes. Add a `mermaid` diagram when it clarifies the flow.
9. **Solution.** The approach you will build, and the main options you weighed. Default to the industry standard from part 6 unless the user wants different; when you diverge, say why in one line.

## Requirements (table tab)

Keep them loose and usable, not a long document. One row per requirement. Each requirement says how the feature is built, what it can do, what it cannot do, and its guardrails. Set `priority` (high, medium, low). Cover the main behavior and the limits that matter; save exhaustive edge cases for when the build proves you need them.

## Testing (table tab, when the feature needs verification)

One row per test, named to match the requirement it checks. Mark each automated or manual against what the repo can actually run. This is the plan for proving the feature, not the test code.

## Design (sidebar attachments, for UI features)

Produce mockups from the project's Storybook when it has one. Attach the screenshots to the spec's queue item so they show in the sidebar. Screenshots do not go in a doc tab. Attach only real images; never invent a URL.
