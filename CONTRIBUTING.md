# Contributing to tap-brewer

Contributions to `tap-brewer` are welcome. Follow the workflow and standards below before opening a pull request.

## Development Setup

Clone the repository and run the local test suite:

```bash
git clone https://github.com/AtaCanYmc/tap-brewer.git
cd tap-brewer
python3 -m unittest discover -s tests -v
```

Validate shell scripts with:

```bash
bash -n scripts/fetch_release_info.sh
```

If `brew` is installed locally, `tests/test_tap_brewer.py` automatically runs `brew style` against rendered versions of all templates under `templates/`.

## Branch Naming

Create a focused branch from `main` using one of these prefixes:

| Prefix | Purpose | Example |
| --- | --- | --- |
| `feat/` | New ecosystem template or workflow capability | `feat/rust-template` |
| `fix/` | Bug fix in scripts, templates, or skill rules | `fix/readme-pipe-escape` |
| `docs/` | Documentation or `SKILL.md` updates | `docs/clarify-poet-note` |
| `chore/` | CI, governance, or maintenance changes | `chore/update-ci-matrix` |

## Commit Convention

All commits must follow [Conventional Commits](https://www.conventionalcommits.org/):

```text
<type>(<scope>): <short imperative summary>
```

Common types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`.

## Pull Request Checklist

- All tests pass via `python3 -m unittest discover -s tests -v`.
- Any changes to `templates/*.rb.tmpl` pass `ruby -c` and `brew style`.
- Scripts remain zero-dependency and executable (`chmod +x`).
- Documentation stays concise, grounded, and free of marketing fluff, emojis, or broken relative links.
- No unrelated files or temporary artifacts are included in the diff.
