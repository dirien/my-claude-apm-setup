---
paths:
  - "pkg/**/*.go"
---

- Every exported symbol needs a doc comment beginning with its name.
- Wrap errors with `fmt.Errorf("...: %w", err)`; never discard an error silently.
- Keep packages small and single-purpose; no cyclic imports.
- Prefer table-driven tests and `gofmt`/`golangci-lint`-clean code.
