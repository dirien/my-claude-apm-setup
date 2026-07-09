# APM automation for this Claude Code + Codex setup. Every recipe runs in CI
# (.github/workflows/apm.yml) and was verified on apm 0.22.0. Targets: claude, codex.

# Reproducible SBOM timestamp — the commit date, or a fixed fallback.
SOURCE_DATE ?= $(shell git log -1 --format=%cI 2>/dev/null || echo 2026-01-01T00:00:00+00:00)

.DEFAULT_GOAL := help
.PHONY: help install sync check ci-install sbom bundle

help: ## Show these targets
	@grep -E '^[a-z-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-11s\033[0m %s\n",$$1,$$2}'

install: ## Resolve deps and wire everything into .claude/ and .codex/
	apm install

sync: ## Regenerate agent context from .apm/instructions (run after editing them)
	apm compile -t claude,codex --clean

check: ## CI gate: primitives valid AND generated context not stale
	apm compile -t claude,codex --validate
	apm compile -t claude,codex --clean --local-only
	@git diff --exit-code AGENTS.md .claude/rules/ || \
		{ echo "ERROR: agent context is stale — run 'make sync' and commit."; exit 1; }

ci-install: ## npm-ci equivalent: reproduce pinned deps, fail on drift
	apm install --frozen
	apm audit --ci

sbom: ## Agent-dependency SBOM (CycloneDX + SPDX), offline and reproducible
	@mkdir -p sbom
	apm lock export -f cyclonedx --timestamp $(SOURCE_DATE) -o sbom/agents.cdx.json
	apm lock export -f spdx      --timestamp $(SOURCE_DATE) -o sbom/agents.spdx.json

bundle: ## Offline release zip so consumers skip cloning the skill repos
	apm install
	apm pack --archive
