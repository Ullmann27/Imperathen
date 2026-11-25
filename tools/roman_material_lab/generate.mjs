import {mkdirSync,writeFileSync} from "node:fs";
import {resolve} from "node:path";
import {specs,generate,png,validate} from "./core.mjs";
const n=Number(process.argv[2]||256);if(![256,512,1024,2048].includes(n))throw Error("Resolution: 256,512,1024,2048");
const out=resolve(process.argv[3]||"prototype/assets/roman_material_lab");mkdirSync(out,{recursive:true});
const stats=[];for(const s of specs){const m=generate(s,n),q=validate(m,n,s),again=generate(s,n);for(const k of Object.keys(m)){if(m[k].some((v,i)=>v!==again[k][i]))throw Error("not deterministic");writeFileSync(resolve(out,s.id+"_"+k+".png"),png(m[k],n));}stats.push({id:s.id,...q});}
if(!(stats[0].mean_roughness>stats[1].mean_roughness&&stats[1].mean_roughness>stats[2].mean_roughness&&stats[2].mean_roughness>stats[3].mean_roughness))throw Error("iron tier roughness");console.log(JSON.stringify({resolution:n,materials:stats},null,2));
