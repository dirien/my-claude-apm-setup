---
description: Rules for Go package code under pkg/
applyTo: "pkg/**/*.go"
---

- Every exported symbol needs a doc comment beginning with its name.
- Wrap errors with `fmt.Errorf("...: %w", err)`; never discard an error silently.
- Keep packages small and single-purpose; no cyclic imports.
- Follow the interface + registry pattern used across `pkg/` (Handler/Provider/Skill/Agent/Command interfaces, each with a Registry).
