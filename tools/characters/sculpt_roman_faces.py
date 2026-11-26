"""Bake actor identity morphs on the two existing close LODs, preserving approved rigs.

blender -b -t 2 -P tools/characters/sculpt_roman_faces.py
The untouched glTF streams retain their original indices and bytes. Only sparse
shape-key deltas and their normal correction are appended. Idempotent on baked files.
"""
import json
import struct
from pathlib import Path

import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SIZES = {5121: 'u1', 5123: '<u2', 5125: '<u4', 5126: '<f4'}


def read_array(doc, binary, index, width):
    accessor = doc['accessors'][index]
    view = doc['bufferViews'][accessor['bufferView']]
    dtype = np.dtype(SIZES[accessor['componentType']])
    return np.ndarray((accessor['count'], width), dtype=dtype, buffer=binary,
                      offset=view.get('byteOffset', 0) + accessor.get('byteOffset', 0),
                      strides=(view.get('byteStride', width * dtype.itemsize), dtype.itemsize)).copy()


def displacement(points, eyes, name):
    # Eyes are the per-archetype landmark. Units are metres in exported Y-up space.
    x, height, z = points.T
    eye_height, eye_front = eyes
    y = height - eye_height
    face = np.clip((z - eye_front + .121) / .085, 0, 1)
    result = np.zeros_like(points)
    if name == 'CastJaw':
        width = np.exp(-np.square((y+.093)/.042)) * face
        result[:, 0] = x * .20 * width
        result[:, 1] = -.009 * np.exp(-np.square(x/.048)) * width
    elif name == 'CastBridge':
        nose = np.exp(-np.square(x/.023) - np.square((y+.026)/.032)) * face
        result[:, 0] = -.20*x*nose
        result[:, 2] = .013*nose
        result[:, 1] = -.003*nose
    elif name == 'CastCheeks':
        cheek = np.exp(-np.square((abs(x)-.047)/.025) - np.square((y+.031)/.025)) * face
        result[:, 2] = .006*cheek
        result[:, 0] = x*.11*cheek
    elif name == 'CastHair':
        # Lift and sweep the frontal locks, without moving the hairline at the temples.
        crest = np.clip((y-.035)/.052,0,1)
        result[:, 0] = .018*crest
        result[:, 1] = .017*crest
        result[:, 2] = .006*crest*face
    return result


def append_vector(doc, binary, delta):
    """A zero base accessor plus sparse vectors avoids dense 0s on the torso."""
    indices = np.flatnonzero(np.max(np.abs(delta), axis=1) > .000015)
    if len(indices) == 0:
        raise ValueError("No affected vertices")
    values = np.asarray(delta[indices], dtype='<f4')

    def add_view(raw):
        binary.extend(b'\0' * (-len(binary) % 4))
        doc['bufferViews'].append({'buffer': 0, 'byteOffset': len(binary), 'byteLength': len(raw)})
        binary.extend(raw)
        return len(doc['bufferViews']) - 1

    index_type = 5123 if len(delta) < 65536 else 5125
    doc['accessors'].append({
        'componentType': 5126, 'count': len(delta), 'type': 'VEC3',
        'min': np.minimum(0,values.min(axis=0)).tolist(), 'max': np.maximum(0,values.max(axis=0)).tolist(),
        'sparse': {'count': len(indices), 'indices': {'bufferView': add_view(indices.astype(SIZES[index_type]).tobytes()),
                                                     'componentType': index_type},
                   'values': {'bufferView': add_view(values.tobytes())}}})
    return len(doc['accessors']) - 1


def bake(path):
    data = path.read_bytes()
    jlength = struct.unpack_from('<I', data, 12)[0]
    doc = json.loads(data[20:20+jlength])
    if doc['asset'].get('extras', {}).get('legio_identity') == 1:
        return
    binary = bytearray(data[28+jlength:])
    meshes = {m['name']: m for m in doc['meshes']}
    eyes = read_array(doc,binary,meshes['HeroEyes']['primitives'][0]['attributes']['POSITION'],3)
    landmark = (eyes[:,1].mean(), eyes[:,2].max())
    targets = {'HeroBody':['CastJaw','CastBridge','CastCheeks']}
    if 'HeroHair' in meshes:
        targets['HeroHair'] = ['CastHair']
    for mesh_name, shapes in targets.items():
        mesh = meshes[mesh_name]
        for part in mesh['primitives']:
            coords = read_array(doc,binary,part['attributes']['POSITION'],3)
            normals = read_array(doc,binary,part['attributes']['NORMAL'],3)
            # Blender shape keys preserve the exact exported vertex order; the
            # serializer emits just their local offsets into the existing GLB.
            surface = bpy.data.meshes.new(mesh_name)
            surface.vertices.add(len(coords))
            surface.vertices.foreach_set('co',coords.ravel())
            obj = bpy.data.objects.new('FaceSculpt',surface)
            obj.shape_key_add(name='Basis')
            for name in shapes:
                key = obj.shape_key_add(name=name)
                offset = displacement(coords,landmark,name)
                key.data.foreach_set('co',(coords+offset).ravel())
                sculpt = np.empty_like(coords)
                key.data.foreach_get('co',sculpt.ravel())
                # Transform the original smooth normals by inverse transpose
                # of the sculpt field, retaining seams and authored shading.
                jac = np.broadcast_to(np.eye(3),(len(coords),3,3)).copy()
                for axis in range(3):
                    step = np.zeros(3,dtype='f4')
                    step[axis] = .0002
                    jac[:,:,axis] += (displacement(coords+step,landmark,name)
                                      - displacement(coords-step,landmark,name))/.0004
                transformed = np.linalg.solve(np.transpose(jac,(0,2,1)), normals[:,:,None])[:,:,0]
                transformed /= np.maximum(.0001,np.linalg.norm(transformed,axis=1))[:,None]
                part.setdefault('targets',[]).append({'POSITION':append_vector(doc,binary,sculpt-coords),
                                                       'NORMAL':append_vector(doc,binary,transformed-normals)})
            bpy.data.objects.remove(obj,do_unlink=True)
            bpy.data.meshes.remove(surface)
        mesh.setdefault('weights',[]).extend([0]*len(shapes))
        mesh.setdefault('extras',{}).setdefault('targetNames',[]).extend(shapes)
    doc['asset'].setdefault('extras',{})['legio_identity'] = 1
    binary.extend(b'\0'*(-len(binary)%4))
    doc['buffers'][0]['byteLength'] = len(binary)
    metadata = json.dumps(doc,separators=(',',':')).encode()
    metadata += b' '*(-len(metadata)%4)
    contents = struct.pack('<I4s',len(metadata),b'JSON')+metadata+struct.pack('<I4s',len(binary),b'BIN\0')+binary
    path.write_bytes(struct.pack('<4sII',b'glTF',2,12+len(contents))+contents)
    print('ROMAN_SCULPT',path.name,len(contents)+12-len(data))


if __name__ == '__main__':
    for path in sorted((ROOT/'prototype/assets/characters').glob('frontier_*_[01].glb')):
        bake(path)
