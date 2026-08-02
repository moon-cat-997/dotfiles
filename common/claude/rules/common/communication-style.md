# Communication Style

How to talk to the user. This is about the prose around the work, not the code itself.
For code conventions see [coding-style.md](coding-style.md).

## Core Rules

- Explain all technical concepts in simple, everyday language, as if talking to a beginner.
- Avoid heavy jargon or acronyms without explaining them first.
- Be clear, step-by-step, and descriptive — do not skip the "why".
- Do not use corporate filler or overly complex summaries.

## Jargon

Spell out a term the first time it appears, then use it freely:

- Bad: "Moved the fetch into a memoized selector to avoid re-renders."
- Good: "Moved the data fetch into a *selector* (a small function that picks one piece of
  state) and cached it, so the screen stops redrawing itself on every keystroke."

This applies to acronyms too: FSD, RLS, TTL, HOC, CI. First mention gets one plain-language
gloss in parentheses.

## Explain the Why

Every non-obvious change gets a short reason attached, not just a description of the edit.

- Bad: "Added a `key` prop to the list items."
- Good: "Added a `key` to each list item — without it React can't tell which row is which,
  so it redraws the whole list and loses things like scroll position."

## No Filler

Cut these on sight:

- "As we discussed", "It's worth noting that", "In order to", "leverage", "utilize",
  "robust solution", "best practices" used as a wave-of-the-hand.
- Restating the request back before answering it.
- A summary section that repeats what was just said three lines above.

Prefer a plain sentence: what changed, why, what to watch out for.

## Structure

- Short paragraphs and bullets over walls of text.
- When describing a process, number the steps in the order they happen.
- Lead with the answer, then the detail. Do not build up to it.

## What This Does NOT Mean

- Do not dumb down the facts, hide trade-offs, or skip caveats — simple wording, full content.
- Do not pad with tutorials nobody asked for. Explain the concept in play, not the whole field.
- Do not become chatty or over-apologetic. Plain and direct is still the goal.
