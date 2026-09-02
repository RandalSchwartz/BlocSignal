# Security Policy

The `BlocSignal` project takes the security and integrity of our reactive state management ecosystem seriously. This document outlines our policy regarding security vulnerability disclosures, supported versions, and response commitments.

---

## Supported Versions

Security updates are actively applied to the latest major and minor release versions published to [pub.dev](https://pub.dev/publishers/blocsignal.dev/packages).

| Package                 | Supported Versions |
| :---------------------- | :----------------- |
| `bloc_signals`          | Latest release     |
| `bloc_signals_flutter`  | Latest release     |
| `bloc_signals_jaspr`    | Latest release     |
| `bloc_signals_riverpod` | Latest release     |
| `bloc_signals_hydrate`  | Latest release     |
| `bloc_signals_replay`   | Latest release     |
| `bloc_signals_otel`     | Latest release     |
| `bloc_signals_devtools` | Latest release     |
| `bloc_signals_test`     | Latest release     |
| `bloc_signals_lint`     | Latest release     |

---

## Reporting a Vulnerability

If you discover a security vulnerability or potential exploit in any `BlocSignal` package or service, please **do not open a public GitHub issue**. Instead, follow responsible disclosure practices:

1. **Email Disclosure**: Send a detailed report directly to **merlyn@stonehenge.com**.
2. **GitHub Security Advisory**: Alternatively, submit a private advisory through the [GitHub Security Advisories](https://github.com/RandalSchwartz/BlocSignal/security/advisories/new) feature on this repository.

### What to Include in Your Report

To help us investigate and remediate the issue efficiently, please include:
- A clear description of the vulnerability and its potential impact.
- The specific package name and version affected.
- Step-by-step instructions or a minimal code example reproducing the issue.
- Any suggested patches, mitigation strategies, or remediations if available.

---

## Response & Disclosure Process

- **Initial Response**: We will acknowledge receipt of your vulnerability report within **48 hours**.
- **Assessment & Fix**: We will work to verify the vulnerability, prepare a patch, and coordinate a fix in a private branch.
- **Coordinated Release**: Once the patch is validated against our 100% test coverage gate, a patched release will be published to pub.dev along with an official security advisory and credit to the reporter (unless anonymity is requested).

