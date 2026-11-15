---
name: optimize-prompt
description: "This skill should be used when the user wants to rewrite a rough prompt into a Claude Code-optimized prompt with appropriate slash commands, structure, and directives for best outcomes."
disable-model-invocation: true
model: opus
effort: high
allowed-tools: [Read, Grep, Glob]
---

# Prompt Optimizer

Take the user's raw prompt and rewrite it into a Claude Code-optimized prompt that will produce the best possible outcome. Ground the rewrite in the real codebase wherever possible — a prompt that names actual files and functions beats a generically well-structured one.

## Input

The user's raw prompt: $ARGUMENTS

## Process

1. **Resolve ambiguity first.** If the prompt is underspecified in a way that would change the rewrite (unclear target, multiple plausible interpretations, missing acceptance criteria), ask 1–3 targeted questions and STOP. Do not optimize a guess. Skip this step only when intent is already clear.

2. **Ground in the codebase.** Use Read / Grep / Glob to find the real files, functions, and patterns the task touches. Replace vague references ("the auth bug") with concrete ones ("the token refresh in `src/auth/session.py:42`"). Look things up — never invent or guess a path; if you can't find it, leave it unspecified and note that.

3. **Classify the task** — bug fix, feature, refactor, research/exploration, ops/infra, code review, migration, documentation.

4. **Assess complexity** — single vs multi-file; isolated vs cross-cutting; straightforward vs deep reasoning.

5. **Select directives** based on classification and complexity. Split them by what can be baked into the prompt vs what the user must run:

   **Bake directly into the prompt body (prompt text — no separate action needed):**
   | Directive | When |
   |-----------|------|
   | `ultrathink` | Single-turn hard reasoning (tricky algorithms, subtle race conditions) |
   | `Continue until: <condition>` | Multi-step tasks needing a completion criterion (text equivalent of `/goal`) |
   | Explicit acceptance criteria | Any task where "done" isn't obvious |

   **Recommend as session commands the user runs first (cannot be baked or pasted):**
   | Command | When |
   |---------|------|
   | `/effort max` | Architecture, complex debugging, security-sensitive work |
   | `/effort high` | Multi-step implementations, non-trivial refactors |
   | `/goal <condition>` | Persistent multi-turn completion criterion (session-level form of the above) |
   | `/plan` | Large multi-file changes, unfamiliar areas, risky modifications |
   | `/compact` | Long multi-phase sessions expected |
   | `/batch` | Repetitive identical changes across many files |
   | `/code-review --fix` | Intent is "find and fix problems in existing code" |
   | `/security-review` | Touching auth, permissions, input handling, or crypto |

6. **Restructure the prompt:**
   - **Context**: What exists now, why the change is needed (1–2 sentences)
   - **Goal**: The end state — specific and testable
   - **Steps** (if multi-step): Numbered, discrete actions
   - **Constraints**: What NOT to do, scope boundaries, things to preserve
   - **Verification**: How to confirm it works (test command, expected output, manual check)

7. **Apply prompt-engineering principles:**
   - Be specific about file paths and function names (now grounded from step 2)
   - State the "why" — Claude makes better decisions with motivation
   - Use imperative voice ("Add X to Y")
   - Scope tightly — one clear ask beats a vague mega-prompt
   - Account for the user's standing CLAUDE.md context where relevant, but do NOT restate it — it's already in every session

## Output Format

```
## Run these first (session commands)
<slash commands the user types into the prompt bar, one per line with a brief why — omit section if none apply>

## Optimized Prompt
<the rewritten prompt, with ultrathink / Continue until / acceptance criteria already baked in — ready to paste>

## Assumptions
<any intent I inferred or specifics I couldn't ground — so you can correct them; omit if none>
```

## Rules

- Resolve real ambiguity with questions before optimizing — don't dress up a guess.
- Ground specifics in the actual codebase; never invent file paths or function names.
- Don't pad with context the user didn't provide and isn't in the code.
- Only include directives that genuinely help this task — not every one, every time.
- As short as possible while fully specified. Don't truncate real detail to hit a length; don't add filler to look thorough.
- Bake prompt-text directives (`ultrathink`, completion criteria) into the prompt itself; only list true session commands under "Run these first."
- If the original prompt is already well-structured and specific, say so and suggest only minor tweaks.
- Always output the final prompt in a fenced code block so it's easy to copy.
