# docs/plans/

One Markdown file per large feature, written before implementation starts.

A plan exists so the design argument is reviewable on its own, separately from
the diff. Anything small enough to hold in one commit does not need one.

## What a plan should contain

- **Goal** — what the feature must do, and how we will know it works.
- **Constraints** — the dependency rules and performance rules it has to respect
  (see `CLAUDE.md`), plus anything the engine forces on us.
- **Approach** — the chosen design, and the alternatives rejected with reasons.
- **Work breakdown** — the components in `systems/` versus the game-specific
  composition in `src/`, in the order they will be built.
- **Open questions** — anything still unresolved. Better recorded than guessed.

Name files after the feature in kebab-case: `client-side-prediction.md`.
Keep a plan updated as the design changes; it is a living document until the
feature lands, and a historical record afterwards.
