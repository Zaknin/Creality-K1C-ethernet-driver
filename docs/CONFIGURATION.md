# Configuration

Build-time configuration is documented in `config/build.env.example`.

Runtime configuration is documented in `config/runtime.conf.example`. The key safety option is:

```sh
KEEP_WIFI_FALLBACK=1
```

When enabled, runtime scripts preserve Wi-Fi default routing unless USB Ethernet proves usable. This protects access paths during validation.

Do not commit local configuration files containing private paths, hostnames, or addresses.

