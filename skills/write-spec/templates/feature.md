# Feature spec template

A feature spec frames the problem before the solution, then lists the requirements and the tests. Cover the sections the work needs: a real feature covers them all, a trivial change may fold or skip the product-framing parts and say which. Write each part lean, a few tight sentences or a table, not walls. Rationale and dead ends go to the spec's memory, not here. Follow `../references/style-guide.md` for the writing.

## Overview (page tab)

Write these parts in order. Each is short.

1. **Objective.** The outcome this delivers, in one line. The what and the why, not the how.
2. **User.** Who it is for, the role or persona. Name them.
3. **Goal and problem.** What the user is trying to do, and the problem they hit today.
4. **Interfaces.** Where this lives, the surfaces it touches: the screens, the API, the CLI.
5. **Core user journeys.** The key flows start to finish, as short numbered steps. Cover the main path and the edges that matter.
6. **Industry standard and best practices.** How the category solves this well, the product, UX, and technical patterns that set the bar. This is the target unless there is a reason to differ.
7. **Current state.** What the product does today for this. Be honest: not supported, or supported but a poor experience, and why. This is the delta the feature closes.
8. **Architecture.** How the feature fits the system: the components, the data model, the contracts, the failure modes. Add a `mermaid` diagram when it clarifies the flow.
9. **Solution and options.** The approach you will build, and the main options considered. Default to the industry-standard pattern from part 6 unless the user wants different; when you diverge, say why in one line.

## Requirements (table tab, and the single build ledger)

One parent row per requirement, written in EARS. One condition, one response, one line.

- Event: When [trigger], the [system] shall [response].
- Unwanted: If [trigger], then the [system] shall [response].
- State: While [precondition], the [system] shall [response].

Cover the main event and the edges that matter: invalid input, permission denied, empty, and error. One row each. Set `priority` (high, medium, low). Each row's title is the requirement; put limits and scope in the description.

Each requirement is a parent row; its implementation steps are child rows beneath it. The requirement is the story, the child steps are the sub-tasks that build it. Each child step names, concisely, what changes, the surfaces it touches, what it depends on, and how you know it is done (Changes / Surfaces / Depends on / Done when). This table is the single ledger: there is no separate implementation plan tab.

## Testing (table tab, when the feature needs verification)

One row per test, traced to a requirement by its title. Label each automated or manual against what the repo can actually run.

## Design (sidebar attachments, for UI features)

Produce mockups from the project's Storybook when it has one. Attach the screenshots to the spec's queue item so they show in the sidebar. Screenshots do not go in a doc tab. Attach only real images; never invent a URL.
