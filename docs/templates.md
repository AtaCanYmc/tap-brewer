[← Back to Docs Index](README.md)

# Formula Templates

All templates under [`templates/`](../templates/) are validated against `ruby -c` and `brew style` on every `make check` run.

## Table of Contents

- [Template Inventory](#template-inventory)
- [Placeholder Reference](#placeholder-reference)
- [Ecosystem Notes](#ecosystem-notes)
- [Local Validation](#local-validation)

## Template Inventory

| Template | Ecosystem | Build Strategy |
| --- | --- | --- |
| [`templates/python.rb.tmpl`](../templates/python.rb.tmpl) | Python (`pyproject.toml`) | `Language::Python::Virtualenv` and `virtualenv_install_with_resources` |
| [`templates/go.rb.tmpl`](../templates/go.rb.tmpl) | Go (`go.mod`) | `go build` with `*std_go_args(ldflags: "-s -w")` |
| [`templates/node.rb.tmpl`](../templates/node.rb.tmpl) | Node.js (`package.json`) | `npm install` with `*std_npm_args` and `bin.install_symlink libexec.glob("bin/*")` |
| [`templates/shell.rb.tmpl`](../templates/shell.rb.tmpl) | Shell (standalone script) | Direct `bin.install` mapping |

Rust projects (`Cargo.toml`) are handled directly in [`SKILL.md`](../SKILL.md) using `depends_on "rust" => :build` and `system "cargo", "install", *std_cargo_args`.

## Placeholder Reference

| Placeholder | Example Value | Used In |
| --- | --- | --- |
| `{{CLASS_NAME}}` | `SampleTool` | All templates |
| `{{DESC}}` | `Inspect local build caches` | All templates |
| `{{HOMEPAGE}}` | `https://github.com/alice/sample-tool` | All templates |
| `{{TARBALL_URL}}` | `https://github.com/alice/sample-tool/archive/refs/tags/v1.0.0.tar.gz` | All templates |
| `{{SHA256}}` | 64-character lowercase hex digest | All templates |
| `{{LICENSE}}` | `MIT` | All templates |
| `{{BIN_NAME}}` | `sample-tool` | All templates |
| `{{PYTHON_DEP}}` | `python@3.13` | `python.rb.tmpl` |
| `{{FORMULA_NAME}}` | `sample-tool` | `python.rb.tmpl` |
| `{{BUILD_PATH}}` | `.` or `./cmd/sample-tool` | `go.rb.tmpl` |
| `{{SOURCE_SCRIPT}}` | `sample-tool.sh` | `shell.rb.tmpl` |

## Ecosystem Notes

- **Python**: When the package declares third-party PyPI dependencies, generate Homebrew `resource` stanzas with `homebrew-pypi-poet` (`poet <package>`) and place them above `def install`.
- **Go**: Set `{{BUILD_PATH}}` to `.` when `main.go` lives at the repository root, or to `./cmd/<binary>` for multi-command layouts.
- **Node.js**: Ensure `package.json` defines a `bin` entry so `libexec.glob("bin/*")` symlinks the executable into Homebrew's `bin`.
- **Shell**: `bin.install "{{SOURCE_SCRIPT}}" => "{{BIN_NAME}}"` installs the script with executable permissions under the target CLI name.

## Local Validation

Render all templates with sample values and run `ruby -c` plus `brew style`:

```bash
make lint-templates
```
