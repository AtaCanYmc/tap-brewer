SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

PYTHON ?= python3
RUBY ?= ruby
SKILL_NAME := tap-brewer

GEMINI_SKILLS_DIR ?= $(HOME)/.gemini/config/skills
CLAUDE_SKILLS_DIR ?= $(HOME)/.claude/skills
CODEX_SKILLS_DIR ?= $(HOME)/.codex/skills
CURSOR_SKILLS_DIR ?= $(HOME)/.cursor/skills

.PHONY: help test lint lint-shell lint-templates lint-docs check \
	install-gemini install-claude install-codex install-cursor install-all uninstall clean

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

test: ## Run unit tests
	$(PYTHON) -m unittest discover -s tests -v

lint-shell: ## Validate shell scripts with bash -n (and shellcheck if installed)
	@for f in scripts/*.sh; do \
		bash -n "$$f"; \
		if command -v shellcheck >/dev/null 2>&1; then \
			shellcheck "$$f"; \
		fi; \
	done
	@echo "shell lint ok"

lint-templates: ## Render templates and check with ruby -c and brew style
	@$(PYTHON) -c '\
	import shutil, subprocess, sys, tempfile; \
	from pathlib import Path; \
	vals = { \
		"{{CLASS_NAME}}": "SampleTool", \
		"{{DESC}}": "Inspect local build caches", \
		"{{HOMEPAGE}}": "https://github.com/alice/sample-tool", \
		"{{TARBALL_URL}}": "https://github.com/alice/sample-tool/archive/refs/tags/v1.0.0.tar.gz", \
		"{{SHA256}}": "0" * 64, \
		"{{LICENSE}}": "MIT", \
		"{{PYTHON_DEP}}": "python@3.13", \
		"{{FORMULA_NAME}}": "sample-tool", \
		"{{BIN_NAME}}": "sample-tool", \
		"{{BUILD_PATH}}": ".", \
		"{{SOURCE_SCRIPT}}": "sample-tool.sh", \
	}; \
	ruby = shutil.which("$(RUBY)"); \
	brew = shutil.which("brew"); \
	tmp = tempfile.TemporaryDirectory(); \
	fdir = Path(tmp.name) / "Formula"; \
	fdir.mkdir(); \
	files = []; \
	[ (out := fdir / ("sample-" + p.name.replace(".rb.tmpl", ".rb")), \
	   text := p.read_text(encoding="utf-8"), \
	   [text := text.replace(k, v) for k, v in vals.items()], \
	   out.write_text(text, encoding="utf-8"), \
	   files.append(str(out))) for p in sorted(Path("templates").glob("*.rb.tmpl")) ]; \
	[subprocess.run([ruby, "-c", f], check=True, stdout=subprocess.DEVNULL) for f in files] if ruby else None; \
	subprocess.run([brew, "style", *files], check=True) if brew else print("brew not found; skipped brew style"); \
	tmp.cleanup()'
	@echo "template lint ok"

lint-docs: ## Validate governance files, internal markdown links, JSON, and YAML
	@for f in README.md SKILL.md LICENSE CONTRIBUTING.md SECURITY.md ROADMAP.md; do \
		test -f "$$f" || { echo "Missing $$f" >&2; exit 1; }; \
	done
	@$(PYTHON) -c '\
	import glob, json, os, re, sys; \
	[json.load(open(f, encoding="utf-8")) for f in [".markdownlint.json", "release-please-config.json", ".release-please-manifest.json"]]; \
	forbidden = re.compile(r"\b(seamlessly|blazingly fast|cutting-edge|revolutionary|comprehensive and robust|effortlessly)\b", re.I); \
	broken = []; \
	for f in glob.glob("**/*.md", recursive=True): \
		raw = open(f, encoding="utf-8").read(); \
		assert "—" not in raw, f"em-dash in {f}"; \
		assert not forbidden.search(raw), f"forbidden buzzword in {f}"; \
		stripped = re.sub(r"`[^`]*`", "", re.sub(r"```[\s\S]*?```", "", raw)); \
		for link in re.findall(r"\[.*?\]\((?!https?://|mailto:)(.*?)(?:#.*)?\)", stripped): \
			link = link.strip().split("?")[0]; \
			if link and not link.startswith("#") and not os.path.exists(os.path.normpath(os.path.join(os.path.dirname(f), link))): \
				broken.append(f"{f} -> {link}"); \
	assert not broken, f"broken links: {broken}"'
	@if command -v $(RUBY) >/dev/null 2>&1; then \
		$(RUBY) -ryaml -e 'Dir.glob(".github/**/*.{yml,yaml}").each { |f| YAML.load_file(f) }'; \
	fi
	@echo "docs & config lint ok"

lint: lint-shell lint-templates lint-docs ## Run all linters

check: lint test ## Run full local CI suite (lint + test)

install-gemini: ## Symlink skill into Gemini CLI / Antigravity skills dir
	mkdir -p "$(GEMINI_SKILLS_DIR)"
	ln -sfn "$(CURDIR)" "$(GEMINI_SKILLS_DIR)/$(SKILL_NAME)"

install-claude: ## Symlink skill into Claude Code skills dir
	mkdir -p "$(CLAUDE_SKILLS_DIR)"
	ln -sfn "$(CURDIR)" "$(CLAUDE_SKILLS_DIR)/$(SKILL_NAME)"

install-codex: ## Symlink skill into Codex skills dir
	mkdir -p "$(CODEX_SKILLS_DIR)"
	ln -sfn "$(CURDIR)" "$(CODEX_SKILLS_DIR)/$(SKILL_NAME)"

install-cursor: ## Symlink skill into Cursor skills dir
	mkdir -p "$(CURSOR_SKILLS_DIR)"
	ln -sfn "$(CURDIR)" "$(CURSOR_SKILLS_DIR)/$(SKILL_NAME)"

install-all: install-gemini install-claude install-codex install-cursor ## Symlink skill into all supported agent dirs

uninstall: ## Remove installed skill symlinks from all agent dirs
	rm -f "$(GEMINI_SKILLS_DIR)/$(SKILL_NAME)" \
		"$(CLAUDE_SKILLS_DIR)/$(SKILL_NAME)" \
		"$(CODEX_SKILLS_DIR)/$(SKILL_NAME)" \
		"$(CURSOR_SKILLS_DIR)/$(SKILL_NAME)"

clean: ## Remove Python caches and temporary tap-brewer work directory
	find . -type d -name "__pycache__" -prune -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	rm -rf /tmp/tap-brewer-work
