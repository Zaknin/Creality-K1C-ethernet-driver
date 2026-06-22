# Development Debug Material

This directory is not part of the runtime package.

`usbnet-diag-counters.patch` records the temporary diagnostic instrumentation
used during final qualification. The resulting diagnostic `usbnet.ko` is not
included in this repository's installable package or release archives as a
runtime module.

Only the frozen production modules under `package/modules/` are supported for
v1.0.0 runtime use.
