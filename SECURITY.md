# Security

Do not put credentials, SSH keys, private hostnames, private IP addresses, vendor SDK paths, toolchain paths, or printer logs in this repository.

Deployment scripts require an explicit `--host` value and do not store credentials. Use SSH agent forwarding or key management outside this project.

Before sharing an archive, run:

```sh
python3 tools/scan-release.py .
```

The scanner is conservative and rejects common binary artifacts, private directory names, private path fragments, credentials, hostnames, IPv4 addresses outside documentation examples, and generated modules.

