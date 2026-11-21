# Security Policy

## Supported Versions

Security fixes are applied to the latest release on `main`.

| Version | Supported |
| --- | --- |
| `main` / latest tag | Yes |
| Older releases | No |

## Reporting a Vulnerability

Do not open a public GitHub issue for security vulnerabilities.

Report vulnerabilities privately through one of these channels:

1. GitHub Security Advisories: `https://github.com/AtaCanYmc/tap-brewer/security/advisories/new`
2. Email: `atacanymc@gmail.com` with the subject `[SECURITY] tap-brewer: <brief summary>`

Include the affected file or script, reproduction steps, and potential impact.

## Response SLA

- Initial acknowledgement: within 48 hours.
- Triage and remediation plan: within 5 business days.
- Coordinated disclosure: after a fix is merged and released.

## Security Scope

`tap-brewer` executes local shell commands and interacts with GitHub repositories via `gh`. Reports covering shell injection in `scripts/fetch_release_info.sh`, path traversal in `scripts/refactor_tap_readme.py`, or unsafe git/brew command generation in `SKILL.md` are in scope.
