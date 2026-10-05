#!/usr/bin/env python3
"""Split a .glb into .gltf + .bin and replace its embedded texture with a shared external PNG.

Usage: glb_to_gltf.py <shared_texture.png> <out_dir> <file.glb>...
The embedded image must be byte-identical to the shared PNG (checked), so nothing changes visually.
"""
import json, struct, sys, os


def read_glb(path):
    data = open(path, 'rb').read()
    assert data[:4] == b'glTF'
    off, js, binc = 12, None, b''
    while off < len(data):
        ln, typ = struct.unpack_from('<II', data, off)
        chunk = data[off + 8:off + 8 + ln]
        if typ == 0x4E4F534A:
            js = json.loads(chunk)
        elif typ == 0x004E4942:
            binc = chunk
        off += 8 + ln
    return js, binc


def main():
    tex, out_dir, files = sys.argv[1], sys.argv[2], sys.argv[3:]
    tex_bytes = open(tex, 'rb').read()
    tex_name = os.path.basename(tex)
    for path in files:
        js, binc = read_glb(path)
        dropped = set()
        for im in js.get('images', []):
            if 'bufferView' in im:
                bv = js['bufferViews'][im['bufferView']]
                blob = binc[bv.get('byteOffset', 0):bv.get('byteOffset', 0) + bv['byteLength']]
                if blob != tex_bytes:
                    sys.exit(f'{path}: embedded image differs from {tex_name}')
                dropped.add(im.pop('bufferView'))
                im.pop('mimeType', None)
                im['uri'] = tex_name
        # Compact the binary buffer: keep only referenced bufferViews, 4-byte aligned.
        remap, new_views, out = {}, [], bytearray()
        for i, bv in enumerate(js['bufferViews']):
            if i in dropped:
                continue
            start = bv.get('byteOffset', 0)
            blob = binc[start:start + bv['byteLength']]
            while len(out) % 4:
                out.append(0)
            nbv = dict(bv)
            nbv['byteOffset'] = len(out)
            out += blob
            remap[i] = len(new_views)
            new_views.append(nbv)
        js['bufferViews'] = new_views
        for acc in js.get('accessors', []):
            if 'bufferView' in acc:
                acc['bufferView'] = remap[acc['bufferView']]
            if 'sparse' in acc:
                acc['sparse']['indices']['bufferView'] = remap[acc['sparse']['indices']['bufferView']]
                acc['sparse']['values']['bufferView'] = remap[acc['sparse']['values']['bufferView']]
        base = os.path.basename(path)
        for suffix in ('.gltf.glb', '.glb'):
            if base.endswith(suffix):
                base = base[:-len(suffix)]
                break
        while len(out) % 4:
            out.append(0)
        js['buffers'] = [{'byteLength': len(out), 'uri': base + '.bin'}]
        open(os.path.join(out_dir, base + '.bin'), 'wb').write(out)
        with open(os.path.join(out_dir, base + '.gltf'), 'w') as f:
            json.dump(js, f, separators=(',', ':'))
        print(f'{base}: bin {len(binc)} -> {len(out)} bytes')


main()
