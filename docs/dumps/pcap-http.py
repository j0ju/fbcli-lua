#!/usr/bin/env python3
# LICENSE: GPL v2, see lua/LICENSE.txt
#
# Prints the HTTP requests of a pcap file with their responses, in order.
# TCP streams are reassembled by sequence number, bodies are de-chunked and
# gunzipped (no tshark/scapy needed).
#
# usage: zstdcat f.pcap.zst > /tmp/f.pcap; python3 pcap-http.py [--raw] [--headers] /tmp/f.pcap
#   --raw      print the reassembled TCP streams unparsed
#   --headers  also print request and response headers
import collections
import gzip
import struct
import sys
import zlib

args = [a for a in sys.argv[1:] if not a.startswith("--")]
raw = "--raw" in sys.argv
show_headers = "--headers" in sys.argv

data = open(args[0], 'rb').read()
magic = data[:4]
endian = '<' if magic in (b'\xd4\xc3\xb2\xa1', b'\x4d\x3c\xb2\xa1') else '>'
linktype = struct.unpack(endian + 'I', data[20:24])[0]
off = 24
segs = collections.defaultdict(dict)
first_seen = {}
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
    first_seen.setdefault(key, ts + tus / 1e6)
    segs[key].setdefault(seq, payload)

streams = {key: b''.join(s[q] for q in sorted(s)) for key, s in segs.items()}


def parse_messages(buf, is_response):
    """splits a stream into (start line, headers, body) of HTTP messages"""
    msgs = []
    pos = 0
    while pos < len(buf):
        end = buf.find(b'\r\n\r\n', pos)
        if end < 0:
            break
        head = buf[pos:end].decode('latin1').split('\r\n')
        start, headers = head[0], {}
        for line in head[1:]:
            k, _, v = line.partition(':')
            headers[k.strip().lower()] = v.strip()
        pos = end + 4
        body = b''
        if headers.get('transfer-encoding', '').lower() == 'chunked':
            while pos < len(buf):
                nl = buf.find(b'\r\n', pos)
                if nl < 0:
                    break
                size = int(buf[pos:nl].split(b';')[0] or b'0', 16)
                pos = nl + 2
                if size == 0:
                    pos = buf.find(b'\r\n', pos) + 2 if buf.find(b'\r\n', pos) >= 0 else len(buf)
                    break
                body += buf[pos:pos+size]
                pos += size + 2
        elif 'content-length' in headers:
            n = int(headers['content-length'])
            body, pos = buf[pos:pos+n], pos + n
        elif is_response and not (start.split(' ')[1:2] in (['204'], ['304']) or start.startswith('HTTP/1.1 1')):
            body, pos = buf[pos:], len(buf)
        enc = headers.get('content-encoding', '').lower()
        try:
            if enc == 'gzip':
                body = gzip.decompress(body)
            elif enc == 'deflate':
                body = zlib.decompress(body)
        except Exception as e:
            body = f'(cannot decode {enc} body: {e})'.encode() + body
        msgs.append((start, headers, body))
    return msgs


def show(start, headers, body, prefix):
    print(prefix + start)
    if show_headers:
        for k, v in headers.items():
            print(f"{prefix}{k}: {v}")
    if body:
        print(body.decode('utf-8', 'replace'))


for t, key in sorted((t, k) for k, t in first_seen.items()):
    stream = streams[key]
    if not stream[:16].split(b' ')[0] in (b'GET', b'POST', b'PUT', b'PATCH', b'DELETE', b'HEAD', b'OPTIONS'):
        continue
    if raw:
        print(f"===== {t:.3f} port {key[1]} -> {key[3]}")
        print(stream.decode('latin1'))
        print(streams.get((key[2], key[3], key[0], key[1]), b'').decode('latin1'))
        continue
    requests = parse_messages(stream, False)
    responses = parse_messages(streams.get((key[2], key[3], key[0], key[1]), b''), True)
    for n, req in enumerate(requests):
        print(f"===== {t:.3f} port {key[1]} -> {key[3]} #{n + 1}")
        show(*req, "> ")
        if n < len(responses):
            show(*responses[n], "< ")
