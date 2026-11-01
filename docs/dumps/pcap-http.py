#!/usr/bin/env python3
# LICENSE: GPL v2, see lua/LICENSE.txt
#
# Prints the HTTP traffic of all TCP streams in a pcap file, in order,
# reassembled by sequence number (no tshark/scapy needed).
#
# usage: zstdcat f.pcap.zst > /tmp/f.pcap; python3 pcap-http.py /tmp/f.pcap
import struct, sys, collections
data = open(sys.argv[1], 'rb').read()
magic = data[:4]
endian = '<' if magic in (b'\xd4\xc3\xb2\xa1', b'\x4d\x3c\xb2\xa1') else '>'
linktype = struct.unpack(endian + 'I', data[20:24])[0]
off = 24
segs = collections.defaultdict(dict)
order = []
while off + 16 <= len(data):
    ts, tus, incl, orig = struct.unpack(endian + 'IIII', data[off:off+16]); off += 16
    pkt = data[off:off+incl]; off += incl
    if linktype == 1:
        eth = struct.unpack('!H', pkt[12:14])[0]; p = pkt[14:]
        if eth == 0x8100: eth = struct.unpack('!H', pkt[16:18])[0]; p = pkt[18:]
    elif linktype == 113:
        eth = struct.unpack('!H', pkt[14:16])[0]; p = pkt[16:]
    else:
        continue
    if eth == 0x0800:
        ihl = (p[0] & 15) * 4; proto = p[9]; src, dst = p[12:16], p[16:20]; tot = struct.unpack('!H', p[2:4])[0]; l4 = p[ihl:tot]
    elif eth == 0x86dd:
        proto = p[6]; src, dst = p[8:24], p[24:40]; l4 = p[40:40+struct.unpack('!H', p[4:6])[0]]
    else:
        continue
    if proto != 6: continue
    sp, dp, seq = struct.unpack('!HHI', l4[:8]); doff = (l4[12] >> 4) * 4; payload = l4[doff:]
    if not payload: continue
    key = (src, sp, dst, dp)
    if key not in segs: order.append((ts + tus/1e6, key))
    segs[key].setdefault(seq, payload)
for t, key in sorted(order):
    stream = b''.join(segs[key][s] for s in sorted(segs[key]))
    txt = stream.decode('latin1')
    if 'HTTP/1' not in txt[:300]: continue
    print(f"===== {t:.3f} port {key[1]} -> {key[3]}")
    print(txt)
