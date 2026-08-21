# A/B test spec template

An A/B test spec is an experiment doc. It says what you are testing, why, the arms you compare, how you measure them, and, once it runs, what happened. Keep every part to a few plain sentences or a table. Follow `../references/style-guide.md` for the writing.

## Overview (page tab)

Write these parts in order. The first parts before the test, the results after.

1. **Summary.** One line: what you are testing and the decision it will make. Include the status (planned, running, done) and the dates.
2. **Issue.** The problem or opportunity behind the test. What happens today, and why it is worth testing.
3. **Hypothesis.** What you are testing. If we make this change, then this metric will move, because of this reason.
4. **Arms.** The versions you compare, one line each. The base arm is the current experience, unchanged. Each candidate arm is a change under test.
5. **Metrics.** The primary metric that decides the test and the direction that wins. The guardrail metrics that must not get worse. Any secondary metrics you watch.
6. **Audience and split.** Who is eligible, the traffic share per arm, and how users are assigned.
7. **Duration and size.** How long it runs, and the sample it needs to call a result.
8. **Ship or kill.** The rule you commit to before the data lands: which result ships the candidate, which kills it.

## Results (table tab, filled in after the test runs)

One row per arm: the primary metric, the change against the base arm, the guardrails, and the confidence. End with the decision.

| Arm | Primary metric | vs base arm | Guardrails | Confidence | Decision |
| --- | --- | --- | --- | --- | --- |
| Base arm | | | | | |
| Candidate arm | | | | | |
