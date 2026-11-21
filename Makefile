SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

PYTHON ?= python3
RUBY ?= ruby
SKILL_NAME := tap-brewer

GEMINI_SKILLS_DIR ?= $(HOME)/.gemini/config/skills
GEMINI_PLUGINS_DIR ?= $(HOME)/.gemini/config/plugins
CLAUDE_SKILLS_DIR ?= $(HOME)/.claude/skills
CODEX_SKILLS_DIR ?= $(HOME)/.codex/skills
CURSOR_SKILLS_DIR ?= $(HOME)/.cursor/skills

.PHONY: help test lint lint-shell lint-templates lint-docs lint-plugins check \
	install-gemini install-plugin-antigravity install-claude install-codex install-cursor install-all uninstall clean

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

define LINT_DOCS_PY
import glob, json, os, re, sys

for jf in [".markdownlint.json", "release-please-config.json", ".release-please-manifest.json"]:
    with open(jf, encoding="utf-8") as fh:
        json.load(fh)

forbidden = re.compile(
    r"\b(seamlessly|blazingly fast|cutting-edge|revolutionary|comprehensive and robust|effortlessly)\b",
    re.I,
)
broken = []
for md in glob.glob("**/*.md", recursive=True):
    raw = open(md, encoding="utf-8").read()
    assert "—" not in raw, f"em-dash in {md}"
    assert not forbidden.search(raw), f"forbidden buzzword in {md}"
    stripped = re.sub(r"`[^`]*`", "", re.sub(r"```[\s\S]*?```", "", raw))
    for link in re.findall(r"\[.*?\]\((?!https?://|mailto:)(.*?)(?:#.*)?\)", stripped):
        link = link.strip().split("?")[0]
        if link and not link.startswith("#"):
            target = os.path.normpath(os.path.join(os.path.dirname(md), link))
            if not os.path.exists(target):
                broken.append(f"{md} -> {link}")
if broken:
    print("Broken links:", broken, file=sys.stderr)
    sys.exit(1)
endef
export LINT_DOCS_PY

lint-docs: ## Validate governance files, internal markdown links, JSON, and YAML
	@for f in README.md SKILL.md LICENSE CONTRIBUTING.md SECURITY.md ROADMAP.md; do \
		test -f "$$f" || { echo "Missing $$f" >&2; exit 1; }; \
	done
	@$(PYTHON) -c "$$LINT_DOCS_PY"
	@if command -v $(RUBY) >/dev/null 2>&1; then \
		$(RUBY) -ryaml -e 'Dir.glob(".github/**/*.{yml,yaml}").each { |f| YAML.load_file(f) }'; \
	fi
	@echo "docs & config lint ok"

define LINT_PLUGINS_PY
import json
from pathlib import Path

manifest_paths = [
    "plugin.json",
    "gemini-extension.json",
    ".claude-plugin/plugin.json",
    ".claude-plugin/marketplace.json",
    ".cursor-plugin/plugin.json",
    ".codex-plugin/plugin.json",
]
versions = set()
for rel in manifest_paths:
    data = json.loads(Path(rel).read_text(encoding="utf-8"))
    assert data.get("name") == "tap-brewer", f"unexpected name in {rel}"
    if rel == ".claude-plugin/marketplace.json":
        versions.add(data["metadata"]["version"])
        versions.add(data["plugins"][0]["version"])
    else:
        versions.add(data["version"])

assert len(versions) == 1, f"manifest versions out of sync: {versions}"
for rel in [
    "skills/tap-brewer/SKILL.md",
    "skills/tap-brewer/scripts/fetch_release_info.sh",
    "skills/tap-brewer/templates/python.rb.tmpl",
    "commands/tap-brew.md",
]:
    assert Path(rel).exists(), f"missing plugin asset: {rel}"
endef
export LINT_PLUGINS_PY

lint-plugins: ## Validate plugin manifests, version parity, and bundled skill links
	@$(PYTHON) -c "$$LINT_PLUGINS_PY"
	@echo "plugin lint ok"

lint: lint-shell lint-templates lint-docs lint-plugins ## Run all linters

check: lint test ## Run full local CI suite (lint + test)

install-gemini: ## Symlink skill into Gemini CLI / Antigravity skills dir
	mkdir -p "$(GEMINI_SKILLS_DIR)"
	ln -sfn "$(CURDIR)" "$(GEMINI_SKILLS_DIR)/$(SKILL_NAME)"

install-plugin-antigravity: ## Symlink plugin into Antigravity plugins dir
	mkdir -p "$(GEMINI_PLUGINS_DIR)"
	ln -sfn "$(CURDIR)" "$(GEMINI_PLUGINS_DIR)/$(SKILL_NAME)"

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

uninstall: ## Remove installed skill and plugin symlinks from all agent dirs
	rm -f "$(GEMINI_SKILLS_DIR)/$(SKILL_NAME)" \
		"$(GEMINI_PLUGINS_DIR)/$(SKILL_NAME)" \
		"$(CLAUDE_SKILLS_DIR)/$(SKILL_NAME)" \
		"$(CODEX_SKILLS_DIR)/$(SKILL_NAME)" \
		"$(CURSOR_SKILLS_DIR)/$(SKILL_NAME)"

clean: ## Remove Python caches and temporary tap-brewer work directory
	find . -type d -name "__pycache__" -prune -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	rm -rf /tmp/tap-brewer-work
