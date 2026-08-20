# Feature spec template

A feature spec has up to four parts. Write only what the work needs. Default to the Overview. Follow `../references/style-guide.md` for the writing.

## Overview (page tab, always)

Lead with what the feature does and who it is for, in one or two sentences. Then add only the parts the work needs:

- **System design.** The components and how they connect. Add a `mermaid` diagram if it clarifies the flow.
- **Technical design.** The data model, the contracts, the failure modes. Named and specific.
- **Architecture.** Where this fits in the wider system.

Keep it scannable. Lead each part with its conclusion. Background and rationale go to the spec's memory, not here.

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
