#!/usr/bin/env bash
set -euo pipefail

# Exit codes:
#   1 - missing dependency, auth failure, invalid arguments, or download error
#   2 - repository has no published GitHub releases

usage() {
  cat <<'EOF' >&2
Usage: fetch_release_info.sh [--repo OWNER/REPO] [--tag TAG]

Fetches the latest (or specified) GitHub release tag, canonical archive tarball
URL, and SHA256 checksum, printing JSON to stdout.
EOF
  exit 1
}

die() {
  echo "error: $*" >&2
  exit 1
}

REPO=""
TAG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      [[ $# -ge 2 ]] || die "--repo requires a value"
      REPO="$2"
      shift 2
      ;;
    --tag)
      [[ $# -ge 2 ]] || die "--tag requires a value"
      TAG="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      [[ -z "$REPO" ]] || die "unexpected argument: $1"
      REPO="$1"
      shift
      ;;
  esac
done

command -v gh >/dev/null 2>&1 || die "gh CLI is not installed. Install it from https://cli.github.com/"
command -v curl >/dev/null 2>&1 || die "curl is required but not found in PATH"

if command -v shasum >/dev/null 2>&1; then
  SHA_CMD=(shasum -a 256)
elif command -v sha256sum >/dev/null 2>&1; then
  SHA_CMD=(sha256sum)
else
  die "neither shasum nor sha256sum is available"
fi

if ! gh auth status >/dev/null 2>&1; then
  die "gh CLI is not authenticated. Run 'gh auth login' first."
fi

CWD_DIRTY="false"
if [[ -z "$REPO" ]]; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if [[ -n "$(git status --porcelain 2>/dev/null || true)" ]]; then
      CWD_DIRTY="true"
      echo "warning: working tree has uncommitted changes; release checksum reflects the published GitHub tag." >&2
    fi
  fi

  REPO="$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)"
  [[ -n "$REPO" ]] || die "could not determine GitHub repository from CWD; pass --repo OWNER/REPO"
fi

if [[ ! "$REPO" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]]; then
  die "invalid repository format: '$REPO' (expected OWNER/REPO)"
fi

if [[ -z "$TAG" ]]; then
  # Query latest published non-draft, non-prerelease tag.
  TAG="$(gh release view --repo "$REPO" --json tagName --jq '.tagName' 2>/dev/null || true)"
  if [[ -z "$TAG" ]]; then
    echo "error: no GitHub releases found for $REPO" >&2
    exit 2
  fi
else
  if ! gh release view "$TAG" --repo "$REPO" --json tagName >/dev/null 2>&1; then
    echo "error: release '$TAG' not found for $REPO" >&2
    exit 2
  fi
fi

# Homebrew strict audit requires archive/refs/tags URLs over api.github.com tarballs.
TARBALL_URL="https://github.com/${REPO}/archive/refs/tags/${TAG}.tar.gz"
VERSION="${TAG#v}"

TMP_TARBALL="$(mktemp "${TMPDIR:-/tmp}/tap-brewer-XXXXXX.tar.gz")"
trap 'rm -f "$TMP_TARBALL"' EXIT

if ! curl -fsSL "$TARBALL_URL" -o "$TMP_TARBALL"; then
  die "failed to download tarball from $TARBALL_URL"
fi

if [[ ! -s "$TMP_TARBALL" ]]; then
  die "downloaded tarball is empty: $TARBALL_URL"
fi

SHA256="$("${SHA_CMD[@]}" "$TMP_TARBALL" | awk '{print $1}')"
if [[ ! "$SHA256" =~ ^[0-9a-f]{64}$ ]]; then
  die "failed to compute valid SHA256 checksum"
fi

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s' "$value"
}

cat <<EOF
{
  "repo": "$(json_escape "$REPO")",
  "tag": "$(json_escape "$TAG")",
  "version": "$(json_escape "$VERSION")",
  "tarball_url": "$(json_escape "$TARBALL_URL")",
  "sha256": "$(json_escape "$SHA256")",
  "cwd_dirty": ${CWD_DIRTY}
}
EOF
