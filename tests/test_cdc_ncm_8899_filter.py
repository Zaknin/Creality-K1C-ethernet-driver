#!/usr/bin/env python3
"""Native regression for the actual cdc_ncm RX helper and NTB RX loop."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'source/cdc_ncm.c').read_text()


def extract(start):
    pos = SOURCE.index(start)
    opening = SOURCE.index('{', pos)
    depth = 0
    for i in range(opening, len(SOURCE)):
        if SOURCE[i] == '{':
            depth += 1
        elif SOURCE[i] == '}':
            depth -= 1
            if depth == 0:
                return SOURCE[pos:i + 1]
    raise AssertionError('unterminated C function: ' + start)


helper = extract('static bool cdc_ncm_should_drop_8899(')
rx_fixup = extract('int cdc_ncm_rx_fixup(')
assert 'payload += len;' in rx_fixup, 'filtered bytes must count as NTB payload'
assert rx_fixup.index('len < ETH_HLEN') < rx_fixup.index('cdc_ncm_should_drop_8899(')
assert rx_fixup.index('cdc_ncm_should_drop_8899(') < rx_fixup.index('netdev_alloc_skb_ip_align(')

harness = r'''
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
typedef uint8_t u8;
typedef uint32_t u32;
#define ETH_HLEN 14
#define USB_CDC_NCM_NDP16_NOCRC_SIGN 0x304d434e
#define cpu_to_le32(x) (x)
#define le32_to_cpu(x) (x)
#define le16_to_cpu(x) (x)
#define EXPORT_SYMBOL_GPL(x)
#define netif_dbg(...) ((void)0)
struct usb_cdc_ncm_dpe16 { uint16_t wDatagramIndex, wDatagramLength; };
struct usb_cdc_ncm_ndp16 {
    uint32_t dwSignature;
    uint16_t wLength, wNextNdpIndex;
    struct usb_cdc_ncm_dpe16 dpe16[2];
};
struct sk_buff { unsigned char *data; unsigned int len; };
struct net_device { int unused; };
struct cdc_ncm_ctx { unsigned int rx_max; unsigned int rx_overhead, rx_ntbs; };
struct usbnet { unsigned long data[5]; struct net_device *net; };
static unsigned int delivered, allocated;
static bool drop_l2_8899 = true;
static int cdc_ncm_rx_verify_nth16(struct cdc_ncm_ctx *ctx, struct sk_buff *skb)
{ (void)ctx; (void)skb; return 0; }
static int cdc_ncm_rx_verify_ndp16(struct sk_buff *skb, int ndpoffset)
{ (void)skb; (void)ndpoffset; return 2; }
static struct sk_buff *netdev_alloc_skb_ip_align(struct net_device *net, int len)
{
    struct sk_buff *skb = calloc(1, sizeof(*skb));
    (void)net;
    assert(skb);
    skb->data = malloc(len);
    assert(skb->data);
    allocated++;
    return skb;
}
static u8 *skb_put(struct sk_buff *skb, int len)
{ u8 *ptr = skb->data + skb->len; skb->len += len; return ptr; }
static void usbnet_skb_return(struct usbnet *dev, struct sk_buff *skb)
{ (void)dev; delivered++; free(skb->data); free(skb); }
/* ACTUAL_FUNCTIONS */
static void run_case(unsigned short a, unsigned short b, bool enabled,
                     unsigned int wanted_deliveries)
{
    u8 raw[188] = {0};
    struct sk_buff ntb = { raw, sizeof(raw) };
    struct cdc_ncm_ctx ctx = { 16384, 0, 0 };
    struct net_device net = { 0 };
    struct usbnet dev = { {0}, &net };
    struct usb_cdc_ncm_ndp16 *ndp = (void *)raw;
    dev.data[0] = (unsigned long)&ctx;
    ndp->dwSignature = USB_CDC_NCM_NDP16_NOCRC_SIGN;
    ndp->dpe16[0].wDatagramIndex = 64;
    ndp->dpe16[0].wDatagramLength = 60;
    ndp->dpe16[1].wDatagramIndex = 128;
    ndp->dpe16[1].wDatagramLength = 60;
    raw[64 + 12] = a >> 8; raw[64 + 13] = a & 255;
    raw[128 + 12] = b >> 8; raw[128 + 13] = b & 255;
    drop_l2_8899 = enabled;
    delivered = 0;
    allocated = 0;
    assert(cdc_ncm_rx_fixup(&dev, &ntb) == 1);
    assert(delivered == wanted_deliveries);
    assert(allocated == wanted_deliveries);
    assert(ctx.rx_ntbs == 1);
    assert(ctx.rx_overhead == 68);
}
int main(void)
{
    run_case(0x8899, 0x0800, true, 1);   /* Drop only Realtek */
    run_case(0x8899, 0x0800, false, 2);  /* Runtime toggle off */
    run_case(0x8898, 0x0800, true, 2);   /* Neighbor EtherType survives */
    run_case(0x86dd, 0x0800, true, 2);   /* IPv6 unaffected */
    run_case(0x0806, 0x0800, true, 2);   /* ARP and IPv4 unaffected */
    run_case(0x8899, 0x8899, true, 0);   /* All filtered NTB valid */
    puts("PASS: actual CDC-NCM RX loop / 0x8899 targeted filter");
}
'''
harness = harness.replace('/* ACTUAL_FUNCTIONS */', helper + '\n' + rx_fixup)

with tempfile.TemporaryDirectory() as d:
    src = Path(d) / 'rx.c'
    exe = Path(d) / 'rx'
    src.write_text(harness)
    subprocess.run(['cc', '-std=c99', '-Wall', '-Wextra', '-Werror',
                    '-Wno-sign-compare',
                    str(src), '-o', str(exe)], check=True)
    subprocess.run([str(exe)], check=True)
