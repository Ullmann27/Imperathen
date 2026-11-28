#!/usr/bin/env node
// Conforming transverse refinement of the actual atlased static tribal shoe mesh.
// No proxy/test coordinates participate. Preserve all original faces' surfaces,
// original vertex data, one material and atlas; subdivide shared edges only.
// CLI: node tools/art/refine_tribal_sole_topology.mjs SOURCE DESTINATION EXPECTED_GIT_BLOB_SHA
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { createHash } from "node:crypto";
function refineTribalSoles(source, contactEdge, cap=900) {
  function require(ok, message) { if (!ok) throw new Error(message); }
  const aligned = n => (n+3)&~3;
  const src = new Uint8Array(source);
  const dv = new DataView(src.buffer,src.byteOffset,src.byteLength);
  require(src.length>=28 && dv.getUint32(0,true)===0x46546c67 && dv.getUint32(4,true)===2 && dv.getUint32(8,true)===src.length,"Invalid GLB");
  const jl=dv.getUint32(12,true), bo=28+jl;
  require(dv.getUint32(16,true)===0x4e4f534a && bo<=src.length && dv.getUint32(24+jl,true)===0x004e4942 && bo+dv.getUint32(20+jl,true)===src.length,"Unexpected GLB chunks");
  const d=JSON.parse(String.fromCharCode(...src.slice(20,20+jl)));
  require(d.buffers.length===1 && !d.buffers[0].uri && d.meshes.length===1 && d.meshes[0].primitives.length===1 && d.materials.length===1 && d.images.length===1,"Require one original atlased static mesh");
  require(!d.skins && !d.animations && !d.extensionsRequired && d.nodes.length===1 && d.nodes[0].mesh===0 && !d.nodes[0].matrix && !d.nodes[0].translation && !d.nodes[0].rotation && !d.nodes[0].scale,"Unexpected rig or transform");
  const prim=d.meshes[0].primitives[0], attr=prim.attributes;
  require(Object.keys(attr).sort().join(",")==="NORMAL,POSITION,TEXCOORD_0" && prim.material===0 && (prim.mode??4)===4 && !prim.targets && !prim.extensions,"Unexpected vertex layout");
  const ac=[attr.POSITION,attr.NORMAL,attr.TEXCOORD_0,prim.indices].map(i=>d.accessors[i]);
  require(ac.every(a=>!a.sparse && !a.normalized && !a.byteOffset) && ac[0].componentType===5126 && ac[1].componentType===5126 && ac[2].componentType===5126 && ac[3].componentType===5123 && ac[0].type==="VEC3" && ac[1].type==="VEC3" && ac[2].type==="VEC2" && ac[3].type==="SCALAR","Unexpected accessor storage");
  const vids=ac.map(a=>a.bufferView), imageView=d.images[0].bufferView;
  require(d.bufferViews.length===5 && new Set([...vids,imageView]).size===5 && d.bufferViews.every(v=>v.buffer===0 && !v.byteStride && !v.extensions && (v.byteOffset??0)+v.byteLength<=d.buffers[0].byteLength),"Require five distinct packed geometry/atlas views");
  function rows(a,width) {
    const v=d.bufferViews[a.bufferView], off=bo+(v.byteOffset??0);
    require(v.byteLength===a.count*width*4,"Invalid float accessor size");
    return Array.from({length:a.count},(_,i)=>Array.from({length:width},(_,k)=>dv.getFloat32(off+4*(i*width+k),true)));
  }
  const p=rows(ac[0],3), n=rows(ac[1],3), uv=rows(ac[2],2);
  require(p.length===n.length && p.length===uv.length && p.flat().every(Number.isFinite) && n.flat().every(Number.isFinite) && uv.flat().every(Number.isFinite),"Invalid vertex data");
  const iv=d.bufferViews[vids[3]], io=bo+(iv.byteOffset??0);
  require(ac[3].count%3===0 && iv.byteLength===ac[3].count*2,"Invalid triangle indices");
  let triangles=Array.from({length:ac[3].count/3},(_,i)=>({ids:[0,1,2].map(k=>dv.getUint16(io+2*(3*i+k),true)),parent:i}));
  require(triangles.every(t=>t.ids.every(i=>i<p.length)) && triangles.length<=cap,"Invalid source topology/budget");
  const originalCount=triangles.length, originalVertices=p.length;
  const area=ids=>{const [a,b,c]=ids.map(i=>p[i]);const x=b.map((v,i)=>v-a[i]),y=c.map((v,i)=>v-a[i]);return Math.hypot(x[1]*y[2]-x[2]*y[1],x[2]*y[0]-x[0]*y[2],x[0]*y[1]-x[1]*y[0])*.5;};
  const areas=triangles.map(t=>area(t.ids));
  const pointKey=i=>p[i].join(",");
  const edgeKey=(i,j)=>[pointKey(i),pointKey(j)].sort().join("|");
  const eligible=(a,b)=>a[0]*b[0]>0 && Math.max(a[1],b[1])<=.10 && Math.min(a[1],b[1])>=0 && Math.max(Math.abs(a[0]),Math.abs(b[0]))<=.28;
  // Transverse spacing, not test-probe location, determines resolution.
  // The actual rank shader blends leg movement by abs(x), with a pitch
  // boundary at 0.205m; coarse transverse shoe triangles undersample it.
  function edgeGroups(){
    const groups=new Map();
    for(let i=0;i<triangles.length;i++){
      const ids=triangles[i].ids;
      for(let e=0;e<3;e++){
        const a=p[ids[e]], b=p[ids[(e+1)%3]], key=edgeKey(ids[e],ids[(e+1)%3]);
        if(!groups.has(key))groups.set(key,{key,width:Math.abs(a[0]-b[0]),eligible:eligible(a,b),faces:[]});
        groups.get(key).faces.push([i,e]);
      }
    }
    return [...groups.values()].filter(g=>g.eligible);
  }
  const maxWidth=()=>Math.max(0,...edgeGroups().map(g=>g.width));
  const beforeWidth=maxWidth();
  const splits=[];
  const reserved=contactEdge?.map(i=>pointKey(i)).sort().join("|");
  while(triangles.length+2<=cap){
    const choices=edgeGroups().filter(g=>g.width>.045 && g.faces.length===2 && g.faces[0][0]!==g.faces[1][0]).sort((a,b)=>b.width-a.width||(a.key<b.key?-1:a.key>b.key?1:0));
    if(!choices.length)break;
    const g=(reserved && splits.length===0 ? choices.find(edge=>edge.key===reserved) : choices[0]);
    require(g, "Pinned forefoot edge is not a conforming sole edge");
    const faces=new Map(g.faces), next=[];
    for(let i=0;i<triangles.length;i++){
      const t=triangles[i];
      if(!faces.has(i)){next.push(t);continue;}
      const e=faces.get(i), a=t.ids[e], b=t.ids[(e+1)%3], c=t.ids[(e+2)%3];
      const mid=(arr)=>arr[a].map((v,k)=>Math.fround((v+arr[b][k])*.5));
      const position=mid(p), tex=mid(uv);
      let normal=mid(n);
      const length=Math.hypot(...normal);
      require(length>1e-6,"Degenerate interpolated normal");
      if(!n[a].every((v,k)=>v===n[b][k]))normal=normal.map(v=>Math.fround(v/length));
      const m=p.length;
      p.push(position);n.push(normal);uv.push(tex);
      next.push({ids:[a,m,c],parent:t.parent},{ids:[m,b,c],parent:t.parent});
    }
    triangles=next;
    splits.push({transverse_width_m:g.width,incident_faces:g.faces.length});
  }
  require(splits.length>0 && triangles.length<=cap && p.length<65536,"No safe conforming refinement within budget");
  const sums=Array(originalCount).fill(0);
  for(const t of triangles)sums[t.parent]+=area(t.ids);
  const maximumAreaError=Math.max(...areas.map((a,i)=>Math.abs(a-sums[i])));
  require(areas.every((a,i)=>Math.abs(a-sums[i])<=Math.max(1e-10,a*1e-5)),"Rest surface area changed");
  // Only actual midpoint vertices were added, and every incident face of
  // each selected edge was split, including its duplicated atlas seam.
  function floatBytes(rows){const out=new Uint8Array(rows.length*rows[0].length*4), view=new DataView(out.buffer);let o=0;for(const row of rows)for(const x of row){view.setFloat32(o,x,true);o+=4;}return out;}
  const indexBytes=new Uint8Array(triangles.length*6), idx=new DataView(indexBytes.buffer);let at=0;for(const t of triangles)for(const i of t.ids){idx.setUint16(at,i,true);at+=2;}
  const atlas=d.bufferViews[imageView], image=src.slice(bo+(atlas.byteOffset??0),bo+(atlas.byteOffset??0)+atlas.byteLength);
  const replacements=new Map([[vids[0],floatBytes(p)],[vids[1],floatBytes(n)],[vids[2],floatBytes(uv)],[vids[3],indexBytes],[imageView,image]]);
  let total=0;for(let i=0;i<d.bufferViews.length;i++){const bytes=replacements.get(i);d.bufferViews[i].byteOffset=total;d.bufferViews[i].byteLength=bytes.length;total+=aligned(bytes.length);}
  const bin=new Uint8Array(total);for(let i=0;i<d.bufferViews.length;i++)bin.set(replacements.get(i),d.bufferViews[i].byteOffset);
  require(image.every((v,i)=>bin[d.bufferViews[imageView].byteOffset+i]===v),"Atlas altered");
  d.buffers[0].byteLength=bin.length;for(let i=0;i<3;i++)ac[i].count=p.length;ac[3].count=triangles.length*3;
  const json=JSON.stringify(d), jp=aligned(json.length);require([...json].every(c=>c.charCodeAt(0)<128),"Unexpected non-ASCII source metadata");
  const out=new Uint8Array(28+jp+bin.length), header=new DataView(out.buffer);
  header.setUint32(0,0x46546c67,true);header.setUint32(4,2,true);header.setUint32(8,out.length,true);header.setUint32(12,jp,true);header.setUint32(16,0x4e4f534a,true);
  out.fill(32,20,20+jp);for(let i=0;i<json.length;i++)out[20+i]=json.charCodeAt(i);
  header.setUint32(20+jp,bin.length,true);header.setUint32(24+jp,0x004e4942,true);out.set(bin,28+jp);
  return {bytes:out,report:{source_triangles:originalCount,candidate_triangles:triangles.length,source_vertices:originalVertices,candidate_vertices:p.length,materials:1,atlas_bytes:image.length,atlas_unchanged:true,max_rest_area_error_m2:maximumAreaError,max_transverse_edge_before_m:beforeWidth,max_transverse_edge_after_m:maxWidth(),splits}};
}
const [input, output, expected] = process.argv.slice(2);
if (!input || !output || !/^[0-9a-f]{40}$/.test(expected ?? "") || existsSync(output)) throw new Error("Provide source, new output and pinned git blob SHA");
const raw=readFileSync(input);
const sha=createHash("sha1").update("blob "+raw.length+"\0").update(raw).digest("hex");
if (sha!==expected) throw new Error("Source blob identity mismatch");
// Preserve transverse refinement, reserving one split for the swordsman's
// asymmetric right forefoot. The indices refer to this exact source blob.
const forefootByBlob = {"73ecda41fd70fefc1541e1a2631b4a40aa37d5d8": [2242, 2223]};
const result=refineTribalSoles(raw,forefootByBlob[sha]);
writeFileSync(output,result.bytes,{flag:"wx"});
console.log("TRIBAL_SOLE_TOPOLOGY "+JSON.stringify({...result.report,source_git_blob:sha,candidate_git_blob:createHash("sha1").update("blob "+result.bytes.length+"\0").update(result.bytes).digest("hex")}));
