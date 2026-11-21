from __future__ import annotations

import json
import os
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FETCH_SCRIPT = ROOT / "scripts" / "fetch_release_info.sh"
README_SCRIPT = ROOT / "scripts" / "refactor_tap_readme.py"
TEMPLATES_DIR = ROOT / "templates"


class TestRefactorTapReadme(unittest.TestCase):
    def run_script(self, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            ["python3", str(README_SCRIPT), *args],
            capture_output=True,
            text=True,
            check=True,
        )

    def test_creates_new_readme_when_missing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            readme = Path(tmp) / "README.md"
            self.run_script(
                "--readme", str(readme),
                "--formula", "beta-cli",
                "--description", "Inspect local caches",
                "--tap", "alice/tap",
                "--source", "https://github.com/alice/beta-cli",
            )
            text = readme.read_text(encoding="utf-8")
            self.assertIn("# alice/tap\n", text)
            self.assertIn("## Formulas\n", text)
            self.assertIn(
                "| `beta-cli` | Inspect local caches | `brew install alice/tap/beta-cli` | [alice/beta-cli](https://github.com/alice/beta-cli) |",
                text,
            )

    def test_appends_section_when_table_missing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            readme = Path(tmp) / "README.md"
            readme.write_text("# Personal Tap\n\nSome intro.\n", encoding="utf-8")
            self.run_script(
                "--readme", str(readme),
                "--formula", "alpha",
                "--description", "Alpha utility",
                "--tap", "alice/tap",
                "--source", "https://github.com/alice/alpha",
            )
            text = readme.read_text(encoding="utf-8")
            self.assertTrue(text.startswith("# Personal Tap\n\nSome intro.\n\n## Formulas\n"))

    def test_inserts_sorted_and_updates_in_place_preserving_surrounding_text(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            readme = Path(tmp) / "README.md"
            readme.write_text(
                "# Tap\n\n"
                "## Formulas\n\n"
                "| Formula | Description | Install | Source |\n"
                "| --- | --- | --- | --- |\n"
                "| `zeta` | Zeta tool | `brew install alice/tap/zeta` | [alice/zeta](https://github.com/alice/zeta) |\n\n"
                "## License\n\nMIT\n",
                encoding="utf-8",
            )
            self.run_script(
                "--readme", str(readme),
                "--formula", "alpha",
                "--description", "Alpha | fast",
                "--tap", "alice/tap",
                "--source", "https://github.com/alice/alpha.git",
            )
            self.run_script(
                "--readme", str(readme),
                "--formula", "zeta",
                "--description", "Updated zeta tool",
                "--tap", "alice/tap",
                "--source", "https://github.com/alice/zeta",
            )
            lines = readme.read_text(encoding="utf-8").splitlines()
            alpha_idx = next(i for i, line in enumerate(lines) if "`alpha`" in line)
            zeta_idx = next(i for i, line in enumerate(lines) if "`zeta`" in line)
            self.assertLess(alpha_idx, zeta_idx)
            self.assertIn("Alpha \\| fast", lines[alpha_idx])
            self.assertIn("[alice/alpha](https://github.com/alice/alpha.git)", lines[alpha_idx])
            self.assertIn("Updated zeta tool", lines[zeta_idx])
            self.assertEqual(lines[-1], "MIT")

    def test_dry_run_does_not_write(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            readme = Path(tmp) / "README.md"
            res = self.run_script(
                "--readme", str(readme),
                "--formula", "demo",
                "--description", "Demo tool",
                "--tap", "alice/tap",
                "--source", "https://example.com/demo",
                "--dry-run",
            )
            self.assertFalse(readme.exists())
            self.assertIn("[Source](https://example.com/demo)", res.stdout)


class TestFetchReleaseInfo(unittest.TestCase):
    def test_script_is_executable_and_valid_bash(self) -> None:
        mode = FETCH_SCRIPT.stat().st_mode
        self.assertTrue(bool(mode & stat.S_IXUSR), "fetch_release_info.sh must be executable")
        subprocess.run(["bash", "-n", str(FETCH_SCRIPT)], check=True)

    def test_missing_gh_returns_exit_1(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            # Expose only minimal PATH without gh.
            env = {"PATH": tmp}
            res = subprocess.run(
                ["/bin/bash", str(FETCH_SCRIPT), "--repo", "alice/demo"],
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertEqual(res.returncode, 1)
            self.assertIn("gh CLI is not installed", res.stderr)

    def test_mocked_gh_and_curl_happy_path_and_no_release(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            bin_dir = Path(tmp) / "bin"
            bin_dir.mkdir()

            mock_gh = bin_dir / "gh"
            mock_gh.write_text(
                "#!/bin/sh\n"
                "if [ \"$1\" = \"auth\" ]; then exit 0; fi\n"
                "if [ \"$1\" = \"release\" ]; then\n"
                "  if [ \"${MOCK_NO_RELEASE:-0}\" = \"1\" ]; then exit 1; fi\n"
                "  echo 'v2.3.4'\n"
                "  exit 0\n"
                "fi\n"
                "exit 1\n",
                encoding="utf-8",
            )
            mock_gh.chmod(0o755)

            mock_curl = bin_dir / "curl"
            mock_curl.write_text(
                "#!/bin/sh\n"
                "out=''\n"
                "while [ $# -gt 0 ]; do\n"
                "  if [ \"$1\" = \"-o\" ]; then out=\"$2\"; shift 2; else shift; fi\n"
                "done\n"
                "printf 'tarball-bytes' > \"$out\"\n",
                encoding="utf-8",
            )
            mock_curl.chmod(0o755)

            env = os.environ.copy()
            env["PATH"] = f"{bin_dir}:{env.get('PATH', '')}"

            ok = subprocess.run(
                [str(FETCH_SCRIPT), "--repo", "alice/demo"],
                env=env,
                capture_output=True,
                text=True,
                check=True,
            )
            payload = json.loads(ok.stdout)
            self.assertEqual(payload["repo"], "alice/demo")
            self.assertEqual(payload["tag"], "v2.3.4")
            self.assertEqual(payload["version"], "2.3.4")
            self.assertEqual(
                payload["tarball_url"],
                "https://github.com/alice/demo/archive/refs/tags/v2.3.4.tar.gz",
            )
            self.assertEqual(len(payload["sha256"]), 64)

            env["MOCK_NO_RELEASE"] = "1"
            missing = subprocess.run(
                [str(FETCH_SCRIPT), "--repo", "alice/demo"],
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertEqual(missing.returncode, 2)


class TestTemplates(unittest.TestCase):
    SAMPLE_VALUES = {
        "{{CLASS_NAME}}": "SampleTool",
        "{{DESC}}": "Inspect local build caches",
        "{{HOMEPAGE}}": "https://github.com/alice/sample-tool",
        "{{TARBALL_URL}}": "https://github.com/alice/sample-tool/archive/refs/tags/v1.0.0.tar.gz",
        "{{SHA256}}": "0" * 64,
        "{{LICENSE}}": "MIT",
        "{{PYTHON_DEP}}": "python@3.13",
        "{{FORMULA_NAME}}": "sample-tool",
        "{{BIN_NAME}}": "sample-tool",
        "{{BUILD_PATH}}": ".",
        "{{SOURCE_SCRIPT}}": "sample-tool.sh",
    }

    def test_all_templates_render_to_valid_ruby(self) -> None:
        templates = sorted(TEMPLATES_DIR.glob("*.rb.tmpl"))
        self.assertEqual(
            [p.name for p in templates],
            ["go.rb.tmpl", "node.rb.tmpl", "python.rb.tmpl", "shell.rb.tmpl"],
        )
        ruby = shutil.which("ruby")
        if not ruby:
            self.skipTest("ruby not available")

        with tempfile.TemporaryDirectory() as tmp:
            formula_dir = Path(tmp) / "Formula"
            formula_dir.mkdir()
            rendered_files = []
            for tmpl in templates:
                rendered = tmpl.read_text(encoding="utf-8")
                for key, val in self.SAMPLE_VALUES.items():
                    rendered = rendered.replace(key, val)
                self.assertNotIn("{{", rendered, f"unreplaced placeholder in {tmpl.name}")
                out_file = formula_dir / f"sample-{tmpl.name.replace('.rb.tmpl', '')}.rb"
                out_file.write_text(rendered, encoding="utf-8")
                rendered_files.append(str(out_file))
                res = subprocess.run([ruby, "-c", str(out_file)], capture_output=True, text=True)
                self.assertEqual(res.returncode, 0, f"{tmpl.name} failed ruby -c: {res.stderr}")

            brew = shutil.which("brew")
            if brew:
                style = subprocess.run([brew, "style", *rendered_files], capture_output=True, text=True)
                self.assertEqual(style.returncode, 0, f"brew style failed:\n{style.stdout}\n{style.stderr}")


class TestPluginManifests(unittest.TestCase):
    MANIFESTS = [
        "plugin.json",
        "gemini-extension.json",
        ".claude-plugin/plugin.json",
        ".claude-plugin/marketplace.json",
        ".cursor-plugin/plugin.json",
        ".codex-plugin/plugin.json",
    ]

    def test_manifests_valid_and_versions_match(self) -> None:
        versions = set()
        for rel in self.MANIFESTS:
            path = ROOT / rel
            self.assertTrue(path.is_file(), f"missing {rel}")
            data = json.loads(path.read_text(encoding="utf-8"))
            self.assertEqual(data.get("name"), "tap-brewer")
            if rel == ".claude-plugin/marketplace.json":
                versions.add(data["metadata"]["version"])
                versions.add(data["plugins"][0]["version"])
            else:
                versions.add(data["version"])
        self.assertEqual(len(versions), 1, f"version mismatch across manifests: {versions}")

    def test_plugin_skill_symlinks_and_command_exist(self) -> None:
        for rel in [
            "skills/tap-brewer/SKILL.md",
            "skills/tap-brewer/scripts/fetch_release_info.sh",
            "skills/tap-brewer/templates/python.rb.tmpl",
            "commands/tap-brew.md",
        ]:
            self.assertTrue((ROOT / rel).exists(), f"missing plugin asset: {rel}")


if __name__ == "__main__":
    unittest.main()
