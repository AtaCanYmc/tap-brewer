#!/usr/bin/env python3
"""Insert or update a formula row in a Homebrew tap README.md table."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from urllib.parse import urlparse

TABLE_HEADER = "| Formula | Description | Install | Source |"
TABLE_SEPARATOR = "| --- | --- | --- | --- |"
GITHUB_HOST_SUFFIX = "github.com"


def escape_cell(text: str) -> str:
    return text.replace("|", "\\|").replace("\n", " ").strip()


def normalize_formula_key(cell: str) -> str:
    cleaned = cell.strip()
    link_match = re.match(r"^\[([^\]]+)\]\([^)]+\)$", cleaned)
    if link_match:
        cleaned = link_match.group(1)
    cleaned = cleaned.strip("`").strip()
    return cleaned.lower()


def format_source_link(source_url: str) -> str:
    parsed = urlparse(source_url)
    label = "Source"
    if parsed.netloc.lower().endswith(GITHUB_HOST_SUFFIX):
        parts = [p for p in parsed.path.strip("/").split("/") if p]
        if len(parts) >= 2:
            repo_name = parts[1].removesuffix(".git") if hasattr(str, "removesuffix") else re.sub(r"\.git$", "", parts[1])
            label = f"{parts[0]}/{repo_name}"
    return f"[{escape_cell(label)}]({source_url.strip()})"


def format_row(formula: str, description: str, tap: str, source_url: str) -> str:
    formula_cell = f"`{escape_cell(formula)}`"
    desc_cell = escape_cell(description)
    install_cell = f"`brew install {escape_cell(tap)}/{escape_cell(formula)}`"
    source_cell = format_source_link(source_url)
    return f"| {formula_cell} | {desc_cell} | {install_cell} | {source_cell} |"


def split_table_cells(line: str) -> List[str]:
    stripped = line.strip()
    if stripped.startswith("|"):
        stripped = stripped[1:]
    if stripped.endswith("|"):
        stripped = stripped[:-1]
    # Split on unescaped pipes only.
    return [cell.strip() for cell in re.split(r"(?<!\\)\|", stripped)]


def is_separator_row(line: str) -> bool:
    cells = split_table_cells(line)
    if not cells:
        return False
    return all(bool(re.match(r"^:?-{3,}:?$", c)) for c in cells)


def is_formula_table_header(line: str) -> bool:
    if "|" not in line:
        return False
    cells = [c.lower() for c in split_table_cells(line)]
    return len(cells) >= 4 and cells[0] == "formula" and "description" in cells and "install" in cells


def find_formula_table(lines: List[str]) -> Optional[Tuple[int, int]]:
    """Return (header_index, end_index_exclusive) for the first formula table."""
    for i in range(len(lines) - 1):
        if is_formula_table_header(lines[i]) and is_separator_row(lines[i + 1]):
            end = i + 2
            while end < len(lines) and lines[end].strip().startswith("|") and "|" in lines[end].strip()[1:]:
                end += 1
            return i, end
    return None


def upsert_table_rows(existing_rows: List[str], formula: str, new_row: str) -> List[str]:
    rows_by_key: Dict[str, str] = {}
    for raw in existing_rows:
        cells = split_table_cells(raw)
        if not cells or not cells[0]:
            continue
        rows_by_key[normalize_formula_key(cells[0])] = raw.strip()

    rows_by_key[formula.strip().lower()] = new_row
    return [rows_by_key[key] for key in sorted(rows_by_key.keys())]


def update_readme_content(
    content: str,
    formula: str,
    description: str,
    tap: str,
    source_url: str,
    section_heading: str = "Formulas",
) -> str:
    new_row = format_row(formula, description, tap, source_url)

    if not content.strip():
        return (
            f"# {tap}\n\n"
            f"## {section_heading}\n\n"
            f"{TABLE_HEADER}\n"
            f"{TABLE_SEPARATOR}\n"
            f"{new_row}\n"
        )

    lines = content.splitlines()
    table_bounds = find_formula_table(lines)

    if table_bounds is not None:
        header_idx, end_idx = table_bounds
        existing_rows = lines[header_idx + 2 : end_idx]
        sorted_rows = upsert_table_rows(existing_rows, formula, new_row)
        updated_lines = (
            lines[: header_idx + 2]
            + sorted_rows
            + lines[end_idx:]
        )
        return "\n".join(updated_lines) + "\n"

    # Append a new section when no formula table exists yet.
    trimmed = content.rstrip("\n")
    return (
        f"{trimmed}\n\n"
        f"## {section_heading}\n\n"
        f"{TABLE_HEADER}\n"
        f"{TABLE_SEPARATOR}\n"
        f"{new_row}\n"
    )


def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Insert or update a Homebrew formula entry in a tap README.md."
    )
    parser.add_argument("--readme", required=True, type=Path, help="Path to the tap README.md")
    parser.add_argument("--formula", required=True, help="Formula name (e.g. my-cli)")
    parser.add_argument("--description", required=True, help="Formula description")
    parser.add_argument("--tap", required=True, help="Tap identifier in user/tap form (e.g. alice/tap)")
    parser.add_argument("--source", required=True, help="Source repository URL")
    parser.add_argument("--section", default="Formulas", help="Heading used when creating the table section")
    parser.add_argument("--dry-run", action="store_true", help="Print updated README to stdout without writing")
    return parser.parse_args(argv)


def main(argv: Optional[List[str]] = None) -> int:
    args = parse_args(argv)
    existing = args.readme.read_text(encoding="utf-8") if args.readme.exists() else ""
    updated = update_readme_content(
        content=existing,
        formula=args.formula,
        description=args.description,
        tap=args.tap,
        source_url=args.source,
        section_heading=args.section,
    )

    if args.dry_run:
        sys.stdout.write(updated)
    else:
        args.readme.parent.mkdir(parents=True, exist_ok=True)
        args.readme.write_text(updated, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
