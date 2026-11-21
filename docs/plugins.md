[← Back to Docs Index](README.md)

# Multi-Agent Plugin Packaging

`tap-brewer` ships both as a standalone root skill (`SKILL.md`) and as a native plugin bundle for Claude Code, Google Antigravity, Gemini CLI, Cursor, and Codex without duplicating source files.

## Table of Contents

- [Supported Plugin Systems](#supported-plugin-systems)
- [Symlink Bundle Layout](#symlink-bundle-layout)
- [Version Synchronization](#version-synchronization)
- [Validation](#validation)

## Supported Plugin Systems

| Platform | Manifest File(s) | Discovery / Install Mechanism |
| --- | --- | --- |
| Claude Code | [`.claude-plugin/plugin.json`](../.claude-plugin/plugin.json), [`.claude-plugin/marketplace.json`](../.claude-plugin/marketplace.json), [`commands/tap-brew.md`](../commands/tap-brew.md) | `claude plugin marketplace add AtaCanYmc/tap-brewer && claude plugin install tap-brewer@tap-brewer` |
| Google Antigravity | [`plugin.json`](../plugin.json) | Clone or symlink into `~/.gemini/config/plugins/tap-brewer` (`make install-plugin-antigravity`) |
| Gemini CLI | [`gemini-extension.json`](../gemini-extension.json) | `gemini extensions install https://github.com/AtaCanYmc/tap-brewer` |
| Cursor | [`.cursor-plugin/plugin.json`](../.cursor-plugin/plugin.json) | Plugin directory or `~/.cursor/skills/tap-brewer` |
| Codex | [`.codex-plugin/plugin.json`](../.codex-plugin/plugin.json) | Plugin directory or `~/.codex/skills/tap-brewer` |
| Skills CLI | Root [`SKILL.md`](../SKILL.md) | `npx skills add AtaCanYmc/tap-brewer` |

## Symlink Bundle Layout

Plugin loaders expect bundled skills under `skills/<skill-name>/SKILL.md`, while standalone skill installs expect `SKILL.md` at the repository root. To maintain a single source of truth, `skills/tap-brewer/` contains relative symlinks:

```text
skills/tap-brewer/
├── SKILL.md -> ../../SKILL.md
├── scripts -> ../../scripts
└── templates -> ../../templates
```

## Version Synchronization

[`release-please-config.json`](../release-please-config.json) tracks every plugin manifest under `extra-files` so semantic version bumps keep all six manifests synchronized automatically on release.

## Validation

Verify JSON validity, version parity across all manifests, and symlink targets:

```bash
make lint-plugins
```
