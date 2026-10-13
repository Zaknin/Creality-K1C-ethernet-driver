#!/usr/bin/env python3
"""Native regression of the *actual* CDC-NCM notification handlers, with USB mocks.

No K1C toolchain or kernel headers needed: extract the two C functions directly
from source/cdc_ncm.c, compile them against minimal host-side stubs, and exercise
duplicate notifications, transitions, split notifications and first 0-bps report.
This does NOT test hardware behavior, module ABI or rx_dropped.
"""
import pathlib
import re
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "source" / "cdc_ncm.c"


def extract_function(text, name):
    match = re.search(r"\bstatic\s+void\s+" + re.escape(name) + r"\s*\(", text)
    if match is None:
        raise AssertionError("missing function " + name)
    opening = text.index("{", match.end())
    level = 0
    for pos in range(opening, len(text)):
        if text[pos] == "{":
            level += 1
        elif text[pos] == "}":
            level -= 1
            if level == 0:
                return text[match.start():pos + 1]
    raise AssertionError("unterminated function " + name)


PREAMBLE = r"""
#include <assert.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
typedef struct { int dummy; } dummy_device;
struct usb_device { dummy_device dev; };
struct net_device { int carrier; };
struct cdc_ncm_ctx { int unused; };
struct usbnet {
    unsigned long data[5];
    unsigned long flags;
    struct net_device *net;
    struct usb_device *udev;
};
struct urb { int actual_length; void *transfer_buffer; };
struct usb_cdc_notification {
    uint8_t bmRequestType;
    uint8_t bNotificationType;
    uint16_t wValue;
    uint16_t wIndex;
    uint16_t wLength;
};
struct usb_cdc_speed_change { uint32_t DLBitRRate; uint32_t ULBitRate; };
#define USB_CDC_NOTIFY_NETWORK_CONNECTION 0x00
#define USB_CDC_NOTIFY_SPEED_CHANGE 0x2a
#define EVENT_STS_SPLIT 0
#define le32_to_cpu(x) (x)
static int conn_logs, speed_logs, link_events;
static void count_info(const char *fmt, ...) {
    if (strstr(fmt, "network connection:")) ++conn_logs;
    if (strstr(fmt, "downlink")) ++speed_logs;
}
#define netif_info(dev, level, net, ...) count_info(__VA_ARGS__)
#define dev_dbg(...) ((void)0)
static int netif_carrier_ok(struct net_device *dev) { return dev->carrier; }
static void usbnet_link_change(struct usbnet *dev, bool up, bool reset) {
    (void)reset;
    ++link_events;
    dev->net->carrier = up;
}
static void set_bit(unsigned int b, unsigned long *v) { *v |= 1UL << b; }
static int test_and_clear_bit(unsigned int b, unsigned long *v) {
    unsigned long mask = 1UL << b;
    int old = !!(*v & mask);
    *v &= ~mask;
    return old;
}
"""

TESTS = r"""
static void send_link(struct usbnet *dev, uint16_t up) {
    struct usb_cdc_notification h = {0};
    struct urb urb = {sizeof(h), &h};
    h.bNotificationType = USB_CDC_NOTIFY_NETWORK_CONNECTION;
    h.wValue = up;
    cdc_ncm_status(dev, &urb);
}
static void send_speed(struct usbnet *dev, uint32_t rx, uint32_t tx) {
    struct {
        struct usb_cdc_notification h;
        struct usb_cdc_speed_change speed;
    } packet = {0};
    struct urb urb = {sizeof(packet), &packet};
    packet.h.bNotificationType = USB_CDC_NOTIFY_SPEED_CHANGE;
    packet.speed.DLBitRRate = rx;
    packet.speed.ULBitRate = tx;
    cdc_ncm_status(dev, &urb);
}
int main(void) {
    struct net_device net = {0};
    struct usb_device udev = {0};
    struct cdc_ncm_ctx ctx = {0};
    struct usbnet dev = {0};
    int i;
    dev.net = &net;
    dev.udev = &udev;
    dev.data[0] = (unsigned long)&ctx;

    /* Initial disconnected status must not create a link event. */
    for (i = 0; i < 100; ++i) send_link(&dev, 0);
    assert(conn_logs == 0 && link_events == 0);

    /* Link up once, then 100 noisy identical indications. */
    send_link(&dev, 1);
    for (i = 0; i < 100; ++i) send_link(&dev, 1);
    assert(net.carrier && conn_logs == 1 && link_events == 1);

    /* First speed report (even 0/0) is observed once. */
    send_speed(&dev, 0, 0);
    for (i = 0; i < 100; ++i) send_speed(&dev, 0, 0);
    assert(speed_logs == 1);

    send_speed(&dev, 1000000000U, 1000000000U);
    for (i = 0; i < 100; ++i)
        send_speed(&dev, 1000000000U, 1000000000U);
    assert(speed_logs == 2);

    /* Only a real speed change is logged. */
    send_speed(&dev, 100000000U, 1000000000U);
    assert(speed_logs == 3);

    /* True carrier-down must be visible exactly once and rearm speed. */
    send_link(&dev, 0);
    for (i = 0; i < 100; ++i) send_link(&dev, 0);
    assert(!net.carrier && conn_logs == 2 && link_events == 2);
    send_speed(&dev, 100000000U, 1000000000U);
    assert(speed_logs == 4);
    send_link(&dev, 1);
    assert(net.carrier && conn_logs == 3 && link_events == 3);

    /* The legacy split speed notification pathway still works. */
    {
        struct usb_cdc_notification h = {0};
        struct usb_cdc_speed_change speed = {1000000000U, 1000000000U};
        struct urb first = {sizeof(h), &h};
        struct urb second = {sizeof(speed), &speed};
        h.bNotificationType = USB_CDC_NOTIFY_SPEED_CHANGE;
        cdc_ncm_status(&dev, &first);
        assert(dev.flags & (1UL << EVENT_STS_SPLIT));
        cdc_ncm_status(&dev, &second);
        assert(!(dev.flags & (1UL << EVENT_STS_SPLIT)));
        assert(speed_logs == 5);
    }

    /* Ignore truncated notifications without changing link state. */
    {
        uint8_t short_packet = 0;
        struct urb urb = {1, &short_packet};
        cdc_ncm_status(&dev, &urb);
        assert(link_events == 3 && conn_logs == 3);
    }

    printf("PASS: deduplicated link/speed, true transitions, 0-bps, split notifications\n");
    return 0;
}
"""


def main():
    source = SOURCE.read_text()
    functions = "\n\n".join(extract_function(source, n)
                            for n in ("cdc_ncm_speed_change", "cdc_ncm_status"))
    with tempfile.TemporaryDirectory() as d:
        path = pathlib.Path(d)
        (path / "regression.c").write_text(PREAMBLE + "\n" + functions + "\n" + TESTS)
        subprocess.run(["cc", "-std=gnu11", "-Wall", "-Wextra",
                        "-Wno-unused-but-set-variable", "-o", str(path / "regression"),
                        str(path / "regression.c")], check=True)
        subprocess.run([str(path / "regression")], check=True)


if __name__ == "__main__":
    main()
