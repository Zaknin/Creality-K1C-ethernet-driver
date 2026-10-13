# Security Policy

## Supported scope

This project provides an unofficial Creality K1C USB Ethernet runtime
and a separate legacy build-tools branch. The **latest ready-to-install
runtime is [v1.0.3](https://github.com/Zaknin/Creality-K1C-ethernet-driver/releases/tag/v1.0.3)**,
physically tested on the 2023 K1C, Linux 4.4.94, with ASIX USB
ID 0b95:1790.

The 2025 K1C revision, different firmware/kernel ABI and other adapters
are not qualified. No product-security guarantee or fixed support
response time is implied.

## Reporting vulnerabilities

For a potentially sensitive security issue, **do not disclose exploit
details, device credentials, API tokens, printer public IP addresses or
private logs in a public GitHub issue**. Prefer GitHub's private
vulnerability reporting/security advisory channel if it is enabled for
this repository, or contact the maintainer privately to arrange
responsible disclosure.

For non-sensitive defects, use the project's
[GitHub issues](https://github.com/Zaknin/Creality-K1C-ethernet-driver/issues).
Always redact credentials and private environment details from logs.

## Safe diagnostics and recovery

- Verify runtime downloads with the release's `SHA256SUMS`.
- Do not load modules compiled for an unrelated kernel/ABI.
- Keep Wi-Fi SSH connectivity when changing USB Ethernet settings.
- Keep a verified known-good runtime archive before upgrading.
- Do not overwrite a currently loaded module or disable the
  recovery path during a first hardware test.

For practical installation and rollback instructions, see the
[current v1.0.3 runtime guide](docs/LATEST-RUNTIME.md).

## License and provenance

This project is independent of Creality. Kernel-derived modules and
their corresponding source retain their upstream/source-file licenses;
the legacy build-tools branch's original scripts are covered by its
`LICENSE`. See the release's `COPYING` and `LICENSE.md` for details.
