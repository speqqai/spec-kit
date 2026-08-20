# Style guide

How to write spec content so a user can scan it while it stays precise for an agent. Rooted in the Minto Pyramid Principle, Amazon's narrative culture, BLUF, plain-language standards, the Google and Microsoft style guides, and EARS.

## Rules

- Lead every section with its conclusion. The first sentence is the answer, not setup.
- One idea per sentence. 15 to 25 words. Hard cap 30.
- Active voice, present tense. Name the actor: "The service retries," not "Retries are performed."
- Start each sentence and bullet with a verb or the key noun. Front-load the load-bearing word.
- Every adjective or claim carries a number, or gets cut. No "fast," "scalable," or "robust" without a figure.
- Tables for parallel data (states, options, fields, error and behavior). Numbered lists for sequences. Prose only for reasoning and tradeoffs.
- Write requirements in EARS. One line, "shall," one condition and one response.
- Depth comes from specific nouns, numbers, and named edge cases, not from more words. Cut any sentence that fails the "so what?" test.

## Banned words

may, might, could, should (as a hedge), significantly, robust, seamless, simply, easily, various, appropriate, leverage, utilize, in order to, a number of, some.

## EARS forms

- Ubiquitous: The [system] shall [response].
- State: While [precondition], the [system] shall [response].
- Event: When [trigger], the [system] shall [response].
- Optional: Where [feature], the [system] shall [response].
- Unwanted: If [trigger], then the [system] shall [response].

## Before and after

- Vague: "The system should handle errors gracefully and provide appropriate feedback." Precise: "If the save request fails, then the editor shall keep the draft in local storage and show 'Changes not saved, retrying.'"
- Bloated: "In order to leverage the new caching layer, various components may need to be significantly refactored." Tight: "Three components read directly from Postgres today. Each must switch to the cache client before launch."
- Buried: "After reviewing polling and webhooks and considering tradeoffs, we decided on webhooks." BLUF: "Use webhooks. Polling adds 30s latency and 10x request volume; webhooks push updates in under 1s."
