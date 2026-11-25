#!/usr/bin/env node
// Strict glTF/GLB reproducibility gate for original IMPERATHEN VIVA assets.
// Byte-for-byte is ideal. Native libm may round final Float32 geometry by a
// few ULPs on a different runner; never reject otherwise identical geometry
// or silently accept different indices, materials, layouts or source topology.
import {readFileSync} from "node:fs";

const FLOAT_ABS_M = 0.000005; // 5 micrometres for metric positions.
const FLOAT_REL = 0.000001;
const MAGIC = 0x46546c67, JSON_CHUNK = 0x4e4f534a, BIN_CHUNK = 0x004e4942;
const COMPONENT_BYTES = {5120:1,5121:1,5122:2,5123:2,5125:4,5126:4};
const TYPES = {SCALAR:1,VEC2:2,VEC3:3,VEC4:4,MAT2:4,MAT3:9,MAT4:16};

function requireValue(ok, label) { if (!ok) throw new Error(label); }

function parseGlb(bytes, name) {
  requireValue(bytes.length >= 28 && bytes.readUInt32LE(0) === MAGIC, name + ": invalid GLB header");
  requireValue(bytes.readUInt32LE(4) === 2 && bytes.readUInt32LE(8) === bytes.length,
    name + ": wrong GLB version or file length");
  const jsonLength = bytes.readUInt32LE(12);
  requireValue(bytes.readUInt32LE(16) === JSON_CHUNK && jsonLength % 4 === 0, name + ": malformed JSON chunk");
  const start = 20 + jsonLength;
  requireValue(start + 8 <= bytes.length, name + ": missing BIN header");
  const binaryLength = bytes.readUInt32LE(start);
  requireValue(bytes.readUInt32LE(start + 4) === BIN_CHUNK && start + 8 + binaryLength === bytes.length,
    name + ": malformed or trailing BIN chunk");
  const document = JSON.parse(bytes.subarray(20,start).toString("utf8").trimEnd());
  requireValue(document.asset?.version === "2.0" && document.buffers?.length === 1 &&
    document.buffers[0].byteLength === binaryLength, name + ": invalid glTF metadata");
  return {document,bytes:bytes.subarray(start+8),name};
}

function near(a,b) {
  return Number.isFinite(a) && Number.isFinite(b) &&
    Math.abs(a-b) <= Math.max(FLOAT_ABS_M, FLOAT_REL*Math.max(Math.abs(a),Math.abs(b)));
}

function compareMetadata(a,b,path="$") {
  if (typeof a !== typeof b) throw new Error(path + ": metadata type changed");
  if (typeof a === "number") {
    if (!near(a,b)) throw new Error(path + ": numeric metadata changed " + a + " / " + b);
    return;
  }
  if (a === null || b === null) {
    requireValue(a === b,path + ": null metadata changed");
    return;
  }
  if (Array.isArray(a)) {
    requireValue(Array.isArray(b) && a.length===b.length,path+": metadata array shape changed");
    for(let i=0;i<a.length;i++) compareMetadata(a[i],b[i],path+"["+i+"]");
    return;
  }
  if(typeof a === "object") {
    requireValue(b && !Array.isArray(b),path+": object metadata changed");
    const ka=Object.keys(a).sort(),kb=Object.keys(b).sort();
    requireValue(JSON.stringify(ka)===JSON.stringify(kb),path+": metadata keys changed");
    for(const key of ka) compareMetadata(a[key],b[key],path+"."+key);
    return;
  }
  requireValue(a===b,path+": categorical metadata changed");
}

function compareGeometry(reference,generated) {
  compareMetadata(reference.document,generated.document);
  const doc=reference.document;
  requireValue(Array.isArray(doc.accessors) && Array.isArray(doc.bufferViews), "missing glTF accessors");
  const observed={floats:0,indices:0,rounding_differences:0,largest_absolute_delta:0,byte_identical:false};
  for(let i=0;i<doc.accessors.length;i++){
    const acc=doc.accessors[i];
    requireValue(Number.isInteger(acc.bufferView) && acc.bufferView < doc.bufferViews.length,
      "missing valid accessor view at "+i);
    requireValue(acc.sparse === undefined && acc.byteOffset === undefined,
      "unexpected sparse or offset accessor at "+i);
    const view=doc.bufferViews[acc.bufferView], width=TYPES[acc.type], bytesPer=COMPONENT_BYTES[acc.componentType];
    requireValue(width && bytesPer && view.byteLength===acc.count*width*bytesPer,
      "accessor byte shape mismatch "+i);
    const offset=view.byteOffset || 0, count=acc.count*width;
    requireValue(offset>=0 && offset+view.byteLength<=reference.bytes.length &&
      offset+view.byteLength<=generated.bytes.length, "out of range accessor "+i);
    if(acc.componentType===5126){
      for(let j=0;j<count;j++){
        const at=offset+j*4;
        const x=reference.bytes.readFloatLE(at),y=generated.bytes.readFloatLE(at);
        requireValue(near(x,y),"real mesh float differs at accessor "+i+" element "+j+": "+x+" vs "+y);
        const delta=Math.abs(x-y);
        observed.largest_absolute_delta=Math.max(observed.largest_absolute_delta,delta);
        if(x!==y) observed.rounding_differences++;
        observed.floats++;
      }
    }else{
      requireValue(reference.bytes.subarray(offset,offset+view.byteLength)
        .equals(generated.bytes.subarray(offset,offset+view.byteLength)),
        "topology, index or integer vertex attribute changed at accessor "+i);
      observed.indices+=count;
    }
  }
  requireValue(reference.bytes.length===generated.bytes.length, "geometry buffer byte length changed");
  observed.byte_identical=reference.bytes.equals(generated.bytes);
  return observed;
}

function selfTest() {
  requireValue(near(0.1,0.1000005) && !near(0.1,0.101), "numeric delta tolerance broken");
  const m={a:[1,"hello",{b:3}]};
  compareMetadata(m,JSON.parse(JSON.stringify(m)));
  let rejected=false;
  try{compareMetadata({indices:[0,1,2]},{indices:[0,1,3]});}catch(_){rejected=true;}
  requireValue(rejected,"metadata mismatch was accepted");
  rejected=false;
  try{compareMetadata({a:[0.0]},{a:[0.0005]});}catch(_){rejected=true;}
  requireValue(rejected,"large geometry change was accepted");
  console.log("GLB_EQUIVALENCE_SELF_TEST_PASS");
}

try{
  if(process.argv.includes("--self-test")) {selfTest();process.exit(0);}
  requireValue(process.argv.length===4,
    "Usage: node tools/viva_roma/verify_props.mjs EXPECTED.glb REBUILT.glb");
  const expected=parseGlb(readFileSync(process.argv[2]),process.argv[2]);
  const rebuilt=parseGlb(readFileSync(process.argv[3]),process.argv[3]);
  const result=compareGeometry(expected,rebuilt);
  console.log("GLB_GEOMETRY_EQUIVALENT "+JSON.stringify({
    expected:process.argv[2],rebuilt:process.argv[3],...result,
    tolerance_abs_metres:FLOAT_ABS_M,tolerance_rel:FLOAT_REL
  }));
}catch(error){
  console.error("GLB_GEOMETRY_MISMATCH "+String(error.message || error));
  process.exitCode=1;
}
