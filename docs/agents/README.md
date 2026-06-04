# Agent training documentation

Instructions for AI coding agents working on hypercluster.

| Document | Purpose |
|----------|---------|
| [training.md](training.md) | Full training guide (architecture, workflows, invariants) |
| [../../AGENTS.md](../../AGENTS.md) | Root quick reference (Cursor / repo agents) |
| [../generated/AGENT-QUICKREF.md](../generated/AGENT-QUICKREF.md) | Auto-generated from repo sources (`make docs`) |
| [../pdf/AGENT-TRAINING.pdf](../pdf/AGENT-TRAINING.pdf) | Printable training PDF |

## How to use with an agent

1. Point the agent at **`AGENTS.md`** for every session (repo root).
2. For k3s/platform work, also provide **`docs/agents/training.md`**.
3. After code changes that affect CLI or config, run **`make docs`** and include updated **`docs/generated/AGENT-QUICKREF.md`** in context.
4. Cursor users: rules in **`.cursor/rules/`** apply automatically.

## Regenerate

```bash
make docs   # updates AGENT-QUICKREF.md, PDFs, index
```
