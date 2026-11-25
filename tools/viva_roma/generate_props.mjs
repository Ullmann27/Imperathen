// Original VIVA Roma geometry; no dependencies. Node >=18.
import {mkdirSync,writeFileSync} from "node:fs";
import {resolve} from "node:path";
function createAsset(kind,lod) {
  const mats = kind==="helmet" ? [
    {name:"Hammered_Bronze",color:[.51,.29,.105],metal:.84,rough:.44},
    {name:"Burnished_Bronze",color:[.64,.39,.16],metal:.91,rough:.30},
    {name:"Interior_Bronze",color:[.27,.16,.064],metal:.75,rough:.64},
    {name:"Leather_Lining",color:[.17,.072,.035],metal:0,rough:.83}
  ] : [
    {name:"Travertine",color:[.64,.56,.43],metal:0,rough:.83},
    {name:"Oak_Dark",color:[.20,.105,.045],metal:0,rough:.79},
    {name:"Oak_Light",color:[.255,.145,.063],metal:0,rough:.74},
    {name:"Forged_Iron",color:[.19,.19,.17],metal:.84,rough:.55},
    {name:"Bronze_Stud",color:[.57,.35,.115],metal:.85,rough:.38}
  ];
  const group=mats.map(()=>({p:[],n:[],uv:[],c:[],i:[]}));
  const sub=(a,b)=>a.map((x,i)=>x-b[i]),add=(a,b)=>a.map((x,i)=>x+b[i]),mul=(a,s)=>a.map(x=>x*s);
  const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
  const unit=a=>{const l=Math.hypot(...a);if(l<1e-12)throw Error("degenerate normal");return mul(a,1/l)};
  function point(g,v,n,uv,tint=1) {
    const i=g.p.length/3; g.p.push(...v);g.n.push(...n);g.uv.push(...uv);
    const variation=1+.035*Math.sin(v[0]*131+v[1]*239+v[2]*181)*Math.sin(v[0]*61-v[1]*89+v[2]*137);
    g.c.push(tint*variation,tint*variation,tint*variation,1);return i;
  }
  function tri(m,a,b,c,tint=1){
    const n=unit(cross(sub(b,a),sub(c,a))),g=group[m];
    const axis=n.map(Math.abs).indexOf(Math.max(...n.map(Math.abs)));
    const uv=v=>axis===0?[v[2],v[1]]:axis===1?[v[0],v[2]]:[v[0],v[1]];
    const x=point(g,a,n,uv(a),tint),y=point(g,b,n,uv(b),tint),z=point(g,c,n,uv(c),tint);g.i.push(x,y,z);
  }
  function quad(m,a,b,c,d,t=1){tri(m,a,b,c,t);tri(m,a,c,d,t)}
  function smoothGrid(m,rows,cols,fn,flip=false,tint=1){
    const g=group[m], start=g.p.length/3, positions=[],normals=[];
    for(let j=0;j<=rows;j++)for(let i=0;i<=cols;i++){positions.push(fn(j/rows,i/cols));normals.push([0,0,0]);}
    const idx=[];
    function face(a,b,c){
      if(flip)[b,c]=[c,b]; const n=cross(sub(positions[b],positions[a]),sub(positions[c],positions[a]));
      if(Math.hypot(...n)<1e-11)return;
      idx.push(a,b,c);for(const i of [a,b,c])normals[i]=add(normals[i],n);
    }
    for(let j=0;j<rows;j++)for(let i=0;i<cols;i++){let a=j*(cols+1)+i,b=a+cols+1;face(a,b,b+1);face(a,b+1,a+1)}
    // Seam-normal continuity for full angular grids.
    for(let j=0;j<=rows;j++){let a=j*(cols+1),b=a+cols;if(Math.hypot(...sub(positions[a],positions[b]))<1e-7){let n=add(normals[a],normals[b]);normals[a]=n;normals[b]=n}}
    for(let j=0;j<=rows;j++)for(let i=0;i<=cols;i++){
      const k=j*(cols+1)+i;point(g,positions[k],unit(normals[k]),[i/cols,j/rows],tint);
    }
    g.i.push(...idx.map(i=>i+start));
  }
  function torus(m,center,major,tube,sides,rings,axis="y",ellipse=1){
    smoothGrid(m,rings,sides,(v,u)=>{
      const a=u*Math.PI*2,b=v*Math.PI*2,q=major+tube*Math.cos(b);
      let p=[q*Math.cos(a),tube*Math.sin(b),q*Math.sin(a)*ellipse];
      if(axis==="z")p=[p[0],p[2],p[1]];
      return add(center,p);
    },axis==="z");
  }
  function sphere(m,center,scale,sides,rings){
    smoothGrid(m,rings,sides,(v,u)=>{
      const a=u*2*Math.PI,b=(.0001+(1-.0002)*v)*Math.PI;
      return add(center,[scale[0]*Math.sin(b)*Math.cos(a),scale[1]*Math.cos(b),scale[2]*Math.sin(b)*Math.sin(a)]);
    },true);
  }
  // Convex beveled solid: a CCW XY profile with a flat front and back,
  // plus visible chamfered side surfaces. Coordinates are in metres.
  function slab(m,poly,z,depth,bevel,tint=1){
    const cx=poly.reduce((s,v)=>s+v[0],0)/poly.length,cy=poly.reduce((s,v)=>s+v[1],0)/poly.length;
    const rings=[[-depth/2,true],[-depth/2+bevel,false],[depth/2-bevel,false],[depth/2,true]].map(([zz,inset])=>poly.map(v=>{
      const dx=v[0]-cx,dy=v[1]-cy,l=Math.hypot(dx,dy),f=inset?Math.max(.1,1-bevel/l):1;
      return [cx+dx*f,cy+dy*f,z+zz];
    }));
    for(let j=0;j<3;j++)for(let i=0;i<poly.length;i++){const k=(i+1)%poly.length;quad(m,rings[j][i],rings[j][k],rings[j+1][k],rings[j+1][i],tint)}
    for(let i=0;i<poly.length;i++){const k=(i+1)%poly.length;tri(m,[cx,cy,z+depth/2],rings[3][i],rings[3][k],tint);tri(m,[cx,cy,z-depth/2],rings[0][k],rings[0][i],tint)}
  }
  function rect(m,x,y,w,h,z,d,b,t=1){slab(m,[[x-w/2,y-h/2],[x+w/2,y-h/2],[x+w/2,y+h/2],[x-w/2,y+h/2]],z,d,b,t)}
  if(kind==="helmet"){
    const n=[80,48,24][lod],rows=[36,22,12][lod];
    const rx=.105,rz=.122,h=.174;
    // The dome is an actual hollow bronze shell, not a solid sphere.
    function shell(inner){
      const thick=.0024,dy=inner?-.0024:0;
      smoothGrid(inner?2:0,rows,n,(v,u)=>{
        const a=u*2*Math.PI, t=v*1.555;
        const taper=Math.pow(Math.cos(t),.88);
        const rX=(rx-(inner?thick:0))*taper,rZ=(rz-(inner?thick:0))*taper;
        const hammer=inner?0: .00032*Math.sin(17*a+11*v)*Math.sin(13*a-19*v);
        return [(rX+hammer)*Math.cos(a),.018+h*Math.sin(t)+dy,(rZ+hammer)*Math.sin(a)];
      },inner);
    }
    shell(false);shell(true);
    // Rolled lip, two raised circumferential bands, and a rounded finial.
    torus(1,[0,.018,0],rx,.0036,n,8,"y",rz/rx);
    torus(1,[0,.031,0],rx*.992,.0015,n,6,"y",rz/rx);
    torus(0,[0,.041,0],rx*.980,.0012,n,6,"y",rz/rx);
    sphere(1,[0,.196,0],[.020,.012,.020],n,12);
    sphere(0,[0,.211,0],[.012,.015,.012],n,12);
    // Rear (+Z) flared guard, shaped in three dimensions.
    const segments=Math.max(12,n/2|0);
    for(let k=0;k<segments;k++){
      const a=.20*Math.PI+k*.60*Math.PI/segments,b=.20*Math.PI+(k+1)*.60*Math.PI/segments;
      const pointGuard=(a,f,yoff=0)=>[(rx+(f*.021))*Math.cos(a),.018-f*.022+yoff,(rz+f*.055)*Math.sin(a)];
      const a0=pointGuard(a,0),b0=pointGuard(b,0),a1=pointGuard(a,1),b1=pointGuard(b,1);
      quad(0,a0,b0,b1,a1);quad(2,pointGuard(a,0,-.003),pointGuard(a,1,-.003),pointGuard(b,1,-.003),pointGuard(b,0,-.003));
      quad(1,a1,b1,pointGuard(b,1,-.003),pointGuard(a,1,-.003));
      if(k===0)quad(1,a0,a1,pointGuard(a,1,-.003),pointGuard(a,0,-.003));
      if(k===segments-1)quad(1,b1,b0,pointGuard(b,0,-.003),pointGuard(b,1,-.003));
    }
    // Curved cheek plates, mirrored, with thickness and hinge studs.
    for(const side of [-1,1]){
      const outline=[[-.057,.018],[-.073,-.020],[-.045,-.055],[-.057,-.101],[-.017,-.125],[.036,-.097],[.056,-.040],[.044,.018]];
      const center=[-.001,-.040];
      const cheek=(p,outer)=>[side*(.103+.012*(1-Math.min(1,Math.abs(p[0])/.08))+.006*Math.sin((p[1]+.125)/.145*Math.PI)+(outer?.002:0)),p[1],p[0]];
      for(let i=0;i<outline.length;i++){
        const j=(i+1)%outline.length,a=cheek(outline[i],true),b=cheek(outline[j],true),c=cheek(center,true),ai=cheek(outline[i],false),bi=cheek(outline[j],false),ci=cheek(center,false);
        if(side>0){tri(0,c,a,b);tri(2,ci,bi,ai);quad(1,a,ai,bi,b)}else{tri(0,c,b,a);tri(2,ci,ai,bi);quad(1,b,bi,ai,a)}
      }
      for(const zz of [-.041,.025])sphere(1,[side*.111,.011,zz],[.004,.004,.004],12,6);
      // Chin-strap attachment and a short dark lining strip.
      sphere(1,[side*.112,-.101,-.012],[.0035,.005,.005],12,6);
      if(lod===0)for(let i=0;i<9;i++)sphere(1,[side*.112,-.057-i*.0055,-.019+i*.001],[.0015,.0018,.0018],8,4);
    }
    // Tiny closed leather brow-pad strip, separate from the metal shell.
    torus(3,[0,.010,0],rx-.006,.0034,Math.max(24,n/2|0),8,"y",rz/rx);
  }else{
    // Architectural module, not a replacement collider: 1.46 m opening,
    // 2.62 m height, inset planks, deep stone reveals and a stepped cornice.
    const z=0;
    for(const side of [-1,1]){
      rect(0,side*.865,1.31,.31,2.62,z,.39,.019);
      rect(0,side*.865,.14,.40,.28,z+.025,.45,.023);
      rect(0,side*.865,2.47,.40,.25,z+.022,.44,.017);
      for(let i=0;i<(lod===0?5:lod===1?3:1);i++){
        let x=side*.865-.105+i*.21/Math.max(1,(lod===0?4:lod===1?2:1));
        rect(0,x,1.31,.018,2.04,z+.201,.026,.005,.94);
      }
    }
    rect(0,0,2.70,2.15,.22,z+.02,.44,.023);
    rect(0,0,2.86,2.25,.10,z+.036,.50,.014);
    rect(0,0,2.96,2.32,.10,z+.048,.54,.012);
    rect(0,0,.045,1.71,.09,z+.04,.46,.009);
    if(lod<2)for(let i=0;i<(lod===0?15:8);i++)rect(0,-.96+i*1.92/((lod===0?15:8)-1),2.78,.085,.058,.255,.05,.008,.97);
    for(const side of [-1,1]){
      for(let i=0;i<5;i++){
        const x=side*(.076+i*.143);rect(i%2?2:1,x,1.27,.137,2.37,.005,.085,.008,.92+.03*i);
        if(lod===0)for(let j=0;j<2;j++)rect(1,x+(j-.5)*.065,1.27,.004,2.18,.051,.009,.002,.82);
      }
      for(const y of [.44,1.20,2.07]){
        rect(2,side*.373,y,.72,.115,.075,.068,.013);
        // Narrow forged strap with flattened ornamental end.
        slab(3,[[side>0?.07:-.70,y-.025],[side>0?.70:-.07,y-.025],[side>0?.70:-.07,y+.025],[side>0?.07:-.70,y+.025]],.122,.021,.004);
        for(let i=0;i<(lod===0?5:lod===1?3:1);i++)sphere(4,[side*(.11+i*.55/Math.max(1,(lod===0?4:lod===1?2:1))),y,.14],[.009,.009,.006],lod===0?12:8,5);
      }
      rect(3,side*.676,1.18,.058,2.04,.123,.035,.006);
      for(const y of [.43,2.07])sphere(3,[side*.72,y,.135],[.037,.066,.030],12,8);
      rect(4,side*.13,1.15,.08,.11,.123,.027,.008);
      torus(4,[side*.13,1.105,.151],.042,.007,lod===0?32:16,8,"z");
    }
  }
  let total=0,bounds=[[Infinity,Infinity,Infinity],[-Infinity,-Infinity,-Infinity]];
  for(const g of group){
    if(g.p.length/3!==g.n.length/3||g.p.length/3!==g.c.length/4||g.p.length/3!==g.uv.length/2)throw Error("attribute lengths");
    for(let i=0;i<g.p.length;i+=3){let n=g.n.slice(i,i+3);if(!n.every(Number.isFinite)||Math.abs(Math.hypot(...n)-1)>1e-5)throw Error("normal");for(let j=0;j<3;j++){const v=g.p[i+j];if(!Number.isFinite(v))throw Error("position");bounds[0][j]=Math.min(bounds[0][j],v);bounds[1][j]=Math.max(bounds[1][j],v)}}
    if(g.i.length%3||g.i.some(i=>!Number.isInteger(i)||i<0||i>=g.p.length/3))throw Error("bad index");
    for(let i=0;i<g.i.length;i+=3){let [a,b,c]=g.i.slice(i,i+3).map(k=>g.p.slice(3*k,3*k+3));if(Math.hypot(...cross(sub(b,a),sub(c,a)))<1e-12)throw Error("degenerate triangle");}
    total+=g.i.length/3;
  }
  if(total<500)throw Error("insufficient geometry");
  const chunks=[],views=[],accessors=[],primitives=[];let offset=0;
  function attr(array,comp,type,target){
    const width=type==="VEC3"?3:type==="VEC2"?2:type==="VEC4"?4:1;
    const data=comp===5126?new Float32Array(array):new Uint32Array(array);
    const bytes=new Uint8Array(data.buffer);const view=views.length;views.push({buffer:0,byteOffset:offset,byteLength:bytes.length,target});chunks.push(bytes);offset+=bytes.length;
    const acc={bufferView:view,componentType:comp,count:array.length/width,type};
    if(type==="VEC3"&&target===34962){acc.min=[Infinity,Infinity,Infinity];acc.max=[-Infinity,-Infinity,-Infinity];for(let i=0;i<array.length;i+=3)for(let j=0;j<3;j++){acc.min[j]=Math.min(acc.min[j],data[i+j]);acc.max[j]=Math.max(acc.max[j],data[i+j])}}
    accessors.push(acc);return accessors.length-1;
  }
  for(let i=0;i<group.length;i++){const g=group[i];if(!g.i.length)continue;primitives.push({attributes:{POSITION:attr(g.p,5126,"VEC3",34962),NORMAL:attr(g.n,5126,"VEC3",34962),TEXCOORD_0:attr(g.uv,5126,"VEC2",34962),COLOR_0:attr(g.c,5126,"VEC4",34962)},indices:attr(g.i,5125,"SCALAR",34963),material:i,mode:4})}
  const name=kind==="helmet"?"Viva_Montefortino_study":"Viva_Taberna_Portal";
  const doc={asset:{version:"2.0",generator:"IMPERATHEN original VIVA mesh generator"},scene:0,scenes:[{nodes:[0]}],nodes:[{name,mesh:0}],meshes:[{name,primitives}],materials:mats.map(m=>({name:m.name,pbrMetallicRoughness:{baseColorFactor:[...m.color,1],metallicFactor:m.metal,roughnessFactor:m.rough},doubleSided:false})),buffers:[{byteLength:offset}],bufferViews:views,accessors,extras:{units:"metres",lod,scope:"original 3D prop study, not historical reconstruction or equipment attachment"}};
  const s=JSON.stringify(doc);const json=new Uint8Array(Math.ceil(s.length/4)*4);json.fill(32);for(let i=0;i<s.length;i++)json[i]=s.charCodeAt(i);
  const out=new Uint8Array(12+8+json.length+8+offset),dv=new DataView(out.buffer);dv.setUint32(0,0x46546c67,true);dv.setUint32(4,2,true);dv.setUint32(8,out.length,true);dv.setUint32(12,json.length,true);dv.setUint32(16,0x4e4f534a,true);out.set(json,20);let q=20+json.length;dv.setUint32(q,offset,true);dv.setUint32(q+4,0x004e4942,true);q+=8;for(const c of chunks){out.set(c,q);q+=c.length}
  return {out,report:{kind,lod,triangles:total,vertices:group.reduce((a,g)=>a+g.p.length/3,0),bounds,bytes:out.length,materials:primitives.length}};
}
const root=resolve(process.argv[2]||"prototype/assets/viva_roma/props");mkdirSync(root,{recursive:true});
const report=[];for(const kind of ["helmet","portal"])for(const lod of [0,1,2]){const a=createAsset(kind,lod);writeFileSync(resolve(root,kind+"_lod"+lod+".glb"),a.out);report.push(a.report);}
for(let i=0;i<6;i+=3)if(!(report[i].triangles>report[i+1].triangles&&report[i+1].triangles>report[i+2].triangles))throw Error("LOD count");
console.log(JSON.stringify(report,null,2));
