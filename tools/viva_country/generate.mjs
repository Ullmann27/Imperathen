// Original metric terrain and 3D scatter geometry. Node.js >=18; no dependencies.
import {mkdirSync,writeFileSync} from "node:fs";
import {resolve} from "node:path";
function generate(){
 const clamp=(x,a=0,b=1)=>Math.max(a,Math.min(b,x)),mix=(a,b,t)=>a+(b-a)*t,smooth=(a,b,v)=>{let t=clamp((v-a)/(b-a));return t*t*(3-2*t)};
 const hash=(x,y,s=0)=>{let a=Math.imul(x|0,374761393)^Math.imul(y|0,668265263)^Math.imul(s+17,1442695041);a=Math.imul(a^(a>>>13),1274126177);return ((a^(a>>>16))>>>0)/4294967295};
 function noise(x,z,s){let i=Math.floor(x),j=Math.floor(z),u=smooth(0,1,x-i),v=smooth(0,1,z-j);return mix(mix(hash(i,j,s),hash(i+1,j,s),u),mix(hash(i,j+1,s),hash(i+1,j+1,s),u),v)}
 const center=z=>1.95*Math.sin(z*.178)+.73*Math.sin(z*.37+.4)-.35;
 const half=z=>1.65+.28*Math.sin(z*.29+.6)+.18*Math.sin(z*.91);
 const edge=(u,z)=>half(z)+.24*(noise(u*2.1,z*1.45,34)-.5)+.12*Math.sin(z*3.6+u*1.7);
 const road=(u,z)=>1-smooth(edge(u,z)-.22,edge(u,z)+.52,Math.abs(u));
 const lane=(u,z)=>Math.exp(-Math.pow((Math.abs(u)-.69-.06*Math.sin(z*.47))/.29,2));
 const prints=[];
 for(let i=0;i<40;i++){
   let z=.90+i*.845+.15*(hash(i,12,7)-.5),u=(i%2===0?-.48:.46)+.22*(hash(i,5,8)-.5)+.13*Math.sin(i*.31);
   if(z<35.4)prints.push({u,z,rx:.071+.021*hash(i,7,9),rz:.096+.025*hash(i,9,10),angle:.32*(hash(i,13,6)-.5),depth:.024+.012*hash(i,4,11)});
 }
 const buckets=Array.from({length:38},()=>[]);
 for(const h of prints)buckets[Math.floor(h.z)].push(h);
 function hoof(u,z){
   let d=0,rim=0;const k=Math.floor(z);
   for(let j=Math.max(0,k-1);j<=Math.min(37,k+1);j++)for(const h of buckets[j]){
     const dx=u-h.u,dz=z-h.z;if(Math.abs(dx)>.16||Math.abs(dz)>.18)continue;
     const c=Math.cos(h.angle),s=Math.sin(h.angle),x=(dx*c-dz*s)/h.rx,y=(dx*s+dz*c)/h.rz,dist=Math.hypot(x,y);
     const heel=smooth(-1.05,-.53,y);
     d=Math.max(d,h.depth*(1-smooth(.52,1.08,dist))*(.52+.48*heel));
     rim=Math.max(rim,.0045*Math.exp(-Math.pow((dist-.97)/.13,2))*heel);
   }
   return {d,rim};
 }
 function height(u,z){
   const m=road(u,z),x=center(z)+u;
   const hills=.23*Math.sin(z*.135)+.11*Math.sin(z*.44+.5)+.027*Math.sin(z*.81);
   const slope=.071*Math.sin(z*.24+.25)*u;
   const meadow=.31*(noise(x*.22,z*.20,12)-.5)+.13*(noise(x*.75,z*.64,14)-.5)+.028*(noise(x*2.7,z*2.4,15)-.5);
   const path=.061*Math.exp(-Math.pow(u/1.1,2))-.033*lane(u,z)+.013*(noise(x*2.8,z*3.2,22)-.5);
   const h=hoof(u,z);
   return hills+slope+mix(meadow,path,m)-h.d+h.rim;
 }
 function shade(u,z){
   let x=center(z)+u,m=road(u,z),a=noise(x*.55,z*.51,26),b=noise(x*3.8,z*3.8,28),h=hoof(u,z),track=lane(u,z)*m;
   const earth=[.37,.267,.155].map((v,i)=>v*(.85+.28*a+.18*b)*(1-.14*track-.26*clamp(h.d/.035)));
   const field=[mix(.153,.225,a),mix(.185,.254,a),mix(.071,.116,a)].map(v=>v*(.91+.16*b));
   return [...field.map((v,i)=>mix(v,earth[i],m)),m];
 }
 const us=[-10];for(let i=1;i<=20;i++)us.push(-10+7*i/20);
 for(let i=1;i<=120;i++)us.push(-3+i*.05);
 for(let i=1;i<=20;i++)us.push(3+7*i/20);
 const dz=.10,nz=120,nu=us.length;
 function gridAt(chunk,u,z){
   const f=(z-chunk*12)/dz,j=clamp(Math.floor(f),0,nz-1),t=clamp(f-j);
   let lo=0,hi=nu-1;while(hi-lo>1){let m=(lo+hi)>>1;if(us[m]<=u)lo=m;else hi=m}
   let q=clamp((u-us[lo])/(us[hi]-us[lo]));
   const za=chunk*12+j*dz,zb=za+dz;
   // Coordinates interpolate linearly between two curved cross sections.
   // The fixed diagonal runs from low-u/low-z to high-u/high-z.
   const a=height(us[lo],za),b=height(us[hi],za),c=height(us[lo],zb),d=height(us[hi],zb);
   const y=q>=t?a+(b-a)*q+(d-b)*t:a+(c-a)*t+(d-c)*q;
   return [mix(center(za),center(zb),t)+u,y,z];
 }
 const mesh=(name,mat)=>({name,mat,p:[],n:[],uv:[],c:[],i:[]});
 const sub=(a,b)=>a.map((v,i)=>v-b[i]),cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]],unit=a=>{let l=Math.hypot(...a);if(l<1e-10)throw Error("degenerate");return a.map(v=>v/l)};
 function vert(g,p,n,c,uv){let i=g.p.length/3;g.p.push(...p);g.n.push(...n);g.c.push(...c.map(v=>clamp(v)));g.uv.push(...uv);return i}
 function tri(g,a,b,c,ca,cb,cc){let n=unit(cross(sub(b,a),sub(c,a)));let k=vert(g,a,n,ca,[a[0],a[2]]);vert(g,b,n,cb,[b[0],b[2]]);vert(g,c,n,cc,[c[0],c[2]]);g.i.push(k,k+1,k+2)}
 const grounds=[];
 for(let k=0;k<3;k++){
  let g=mesh("CountryTerrain_"+k,0);
  for(let j=0;j<=nz;j++){const z=k*12+j*dz;for(const u of us){
    const x=center(z)+u,e=.012;
    const hL=height(u-e,z),hR=height(u+e,z);
    const hB=height(x-center(z-e),z-e),hF=height(x-center(z+e),z+e);
    const n=unit([-(hR-hL)/(2*e),1,-(hF-hB)/(2*e)]);
    vert(g,[x,height(u,z),z],n,shade(u,z),[x,z]);
  }}
  for(let j=0;j<nz;j++)for(let i=0;i<nu-1;i++){let a=j*nu+i,b=a+1,c=a+nu,d=c+1;g.i.push(a,c,d,a,d,b)}
  grounds.push(g);
 }
 const grassSpecs=[["grass_short",.095,6,.115],["grass_medium",.19,7,.15],["grass_tall",.34,7,.20],["grass_dry",.25,5,.14]];
 const grasses=[];
 for(let k=0;k<grassSpecs.length;k++){
   const [name,H,count,span]=grassSpecs[k],g=mesh(name,1);
   for(let b=0;b<count;b++){
    const a=b*2.399963+.8*hash(b,k,40),h=H*(.64+.51*hash(b,k,41)),bend=(.14+.37*hash(b,k,43))*h,w=(.0025+.0036*hash(b,k,44))*(k===0?.80:1),r=span*.31*Math.sqrt(hash(b,k,45)),bx=r*Math.cos(a+1.2),bz=r*Math.sin(a+1.2);
    const colors=t=>{let base=k===3?[.34,.29,.115]:k===0?[.145,.245,.070]:[.112,.245,.053];const light=.78+.43*t+.14*hash(b,k,81),dry=k===3?.7:smooth(.68,1,t)*(.12+.38*hash(b,k,82));return [mix(base[0]*light,.39,dry),mix(base[1]*light,.32,dry),mix(base[2]*light,.10,dry),1]};
    const rings=[];
    const segments=k===2?4:3;
    for(let j=0;j<segments;j++){let t=j/segments,wide=w*Math.pow(1-t,.72);const x=bx+bend*t*t*Math.cos(a),z=bz+bend*t*t*Math.sin(a);rings.push([[-Math.sin(a)*wide,0,-Math.cos(a)*-wide],[Math.sin(a)*wide,0,-Math.cos(a)*wide],[Math.cos(a)*wide*.18,0,Math.sin(a)*wide*.18]].map(v=>[x+v[0],h*t,z+v[2]]))}
    // Full triangular cross section, not a camera-facing billboard.
    for(let j=0;j<segments-1;j++)for(let q=0;q<3;q++){let n=(q+1)%3;tri(g,rings[j][q],rings[j+1][q],rings[j+1][n],colors(j/segments),colors((j+1)/segments),colors((j+1)/segments));tri(g,rings[j][q],rings[j+1][n],rings[j][n],colors(j/segments),colors((j+1)/segments),colors(j/segments))}
    let tip=[bx+bend*Math.cos(a),h,bz+bend*Math.sin(a)];for(let q=0;q<3;q++)tri(g,rings[segments-1][q],tip,rings[segments-1][(q+1)%3],colors((segments-1)/segments),colors(1),colors((segments-1)/segments));
   }
   grasses.push(g);
 }
 const rocks=[];
 for(let k=0;k<4;k++){
   let g=mesh("stone_"+k,2),rings=[],sides=10+k,rows=5;
   for(let j=1;j<rows;j++){let phi=j*Math.PI/rows,ring=[];for(let i=0;i<sides;i++){let a=i*2*Math.PI/sides,rr=.76+.24*hash(i,j,k+80);ring.push([Math.sin(phi)*Math.cos(a)*rr,Math.cos(phi)*(.40+.11*k)*rr,Math.sin(phi)*Math.sin(a)*rr*(.78+.08*k)])}rings.push(ring)}
   const top=[.05,.43+.08*k,-.02],bot=[-.05,-.36-.07*k,.015];
   const color=p=>{let v=.29+.065*k+.075*Math.sin(p[0]*3+p[1]*4+p[2]*5);return [v,v*.94,v*.83,1]};
   function outward(a,b,c){let n=cross(sub(b,a),sub(c,a)),v=a.map((q,i)=>(q+b[i]+c[i])/3);if(n.reduce((s,q,i)=>s+q*v[i],0)<0)[b,c]=[c,b];tri(g,a,b,c,color(a),color(b),color(c))}
   for(let i=0;i<sides;i++){const n=(i+1)%sides;outward(top,rings[0][i],rings[0][n]);for(let j=0;j<rings.length-1;j++){outward(rings[j][i],rings[j+1][i],rings[j+1][n]);outward(rings[j][i],rings[j+1][n],rings[j][n])}outward(bot,rings.at(-1)[n],rings.at(-1)[i])}
   for(let i=0;i<g.p.length;i+=3){const p=g.p.slice(i,i+3),n=g.n.slice(i,i+3),estimate=unit([p[0],p[1]/Math.pow(.43+.08*k,2),p[2]/Math.pow(.78+.08*k,2)]);const q=unit(n.map((v,j)=>.38*v+.62*estimate[j]));g.n.splice(i,3,...q)}
   rocks.push(g);
 }
 const scatter=[],stats={grass:0,stone:0,grassMin:Infinity,grassMax:0,stoneMin:Infinity,stoneMax:0,roadGrass:0,edgeGrass:0,grassTriangles:0,stoneTriangles:0,classes:{fine:0,medium:0,coarse:0},chunks:[]};
 const round=x=>+x.toFixed(5),TAU=2*Math.PI;
 for(let k=0;k<3;k++){
   const groups=Array.from({length:8},()=>[]);let grass=0,stone=0;
   // Stratified jittered meadow; density follows organic patches, wheel tracks and edge.
   for(let i=0;i<112;i++)for(let j=0;j<67;j++){
      const u=-10+(i+hash(i,j,k+100))*20/112,z=k*12+(j+hash(i,j,k+200))*12/67;
      const m=road(u,z),cover=.42+.55*noise((u+center(z))*.51,z*.43,110),near=Math.abs(u)<3.15;
      const stripe=Math.exp(-Math.pow(u/.22,2))*.45;
      const chance=m>.76?(.015+.30*stripe)*(1-.86*lane(u,z)):(near?.76:.62)*cover*(1-.57*m);
      if(hash(i,j,k+300)>chance)continue;
      let a=hash(i,j,k+310),id=m>.55?0:a<.43?0:a<.76?1:a<.91?2:3;
      const sy=(.65+1.0*hash(i,j,k+320))*(m>.5?.62+.30*(1-m):1),sx=.65+.68*hash(i,j,k+330),sz=.75+.62*hash(i,j,k+340);
      const pos=gridAt(k,u,z),h=grassSpecs[id][1]*sy;
      // Grass root is just within the shared continuous terrain.
      groups[id].push([pos[0],pos[1]-.006,z,TAU*hash(i,j,k+350),sx,sy,sz,.87+.13*hash(i,j,k+360),.88+.12*hash(i,j,k+370),.83+.17*hash(i,j,k+380),hash(i,j,k+390)].map(round));
      grass++;stats.grass++;stats.grassMin=Math.min(stats.grassMin,h);stats.grassMax=Math.max(stats.grassMax,h);if(m>.76)stats.roadGrass++;if(m>.2&&m<=.76)stats.edgeGrass++;stats.grassTriangles+=grasses[id].i.length/3;
   }
   // Dense irregular roadside bands with individual 3D blades, not a flat grass sheet.
   for(let j=0;j<96;j++)for(let i=0;i<28;i++){
     const side=i<14?-1:1,step=i%14;
     const z=k*12+(j+hash(i,j,k+610))*.125;
     const u=side*(half(z)-.34+(step+hash(i,j,k+620))*.125);
     const m=road(u,z),cover=noise((u+center(z))*.83,z*.72,145);
     const chance=(.38+.57*cover)*(1-.76*smooth(.52,.95,m))*(1-.85*lane(u,z)*m);
     if(hash(i,j,k+630)>chance)continue;
     const a=hash(i,j,k+640),id=m>.55?0:a<.22?0:a<.65?1:a<.86?2:3;
     const sy=(.72+.88*hash(i,j,k+650))*(m>.5?.60+.32*(1-m):1);
     const sx=1.04+.76*hash(i,j,k+660),sz=.95+.8*hash(i,j,k+670),pos=gridAt(k,u,z),h=grassSpecs[id][1]*sy;
     groups[id].push([pos[0],pos[1]-.006,z,TAU*hash(i,j,k+680),sx,sy,sz,.84+.16*hash(i,j,k+690),.87+.13*hash(i,j,k+700),.80+.20*hash(i,j,k+710),hash(i,j,k+720)].map(round));
     grass++;stats.grass++;stats.grassMin=Math.min(stats.grassMin,h);stats.grassMax=Math.max(stats.grassMax,h);if(m>.76)stats.roadGrass++;if(m>.2&&m<=.76)stats.edgeGrass++;stats.grassTriangles+=grasses[id].i.length/3;
   }
   // Fine gravel is also handled by the terrain shader; these are visible 3D stones.
   for(let j=0;j<120;j++)for(let i=0;i<44;i++){
     const u=-3.3+(i+hash(i,j,k+410))*.15,z=k*12+(j+hash(i,j,k+420))*.10,m=road(u,z);
     if(hash(i,j,k+430)>(.29*m+.045*(1-m))*(.60+.80*noise(u*1.1,z*.77,115)))continue;
     const a=hash(i,j,k+440),id=Math.min(3,Math.floor(hash(i,j,k+450)*4));
     const radius=a<.72?.009+.020*hash(i,j,k+460):a<.94?.029+.025*hash(i,j,k+460):.054+.032*hash(i,j,k+460);
     const pos=gridAt(k,u,z);const sy=radius*(.68+.45*hash(i,j,k+470)),sx=radius*(.78+.46*hash(i,j,k+480)),sz=radius*(.76+.50*hash(i,j,k+490));
     groups[4+id].push([pos[0],pos[1]+sy*.04,z,TAU*hash(i,j,k+500),sx,sy,sz,.8+.2*hash(i,j,k+510),.83+.17*hash(i,j,k+520),.80+.20*hash(i,j,k+530),hash(i,j,k+540)].map(round));
     stone++;stats.stone++;stats.stoneMin=Math.min(stats.stoneMin,radius);stats.stoneMax=Math.max(stats.stoneMax,radius);stats.stoneTriangles+=rocks[id].i.length/3;stats.classes[a<.72?"fine":a<.94?"medium":"coarse"]++;
   }
   for(const rows of groups){rows.sort((a,b)=>a[10]-b[10]);for(const row of rows)row.pop()}
   scatter.push({schema:1,chunk:k,layout:["x","y","z","yaw","sx","sy","sz","r","g","b"],groups:groups.map((rows,i)=>({mesh:[...grasses,...rocks][i].name,rows}))});
   stats.chunks.push({chunk:k,grass,stone,triangles:grounds[k].i.length/3});
 }
 // Verify exact borders, mesh data, soil morphology and population bounds.
 for(let k=0;k<2;k++)for(let i=0;i<nu;i++)for(let c=0;c<3;c++){
    if(Math.abs(grounds[k].p[(nz*nu+i)*3+c]-grounds[k+1].p[i*3+c])>1e-7)throw Error("cracked terrain seam");
    if(Math.abs(grounds[k].n[(nz*nu+i)*3+c]-grounds[k+1].n[i*3+c])>1e-7)throw Error("normal seam");
 }
 const meshes=[...grounds,...grasses,...rocks];
 for(const g of meshes){
   if(g.p.length/3!==g.n.length/3||g.c.length/4!==g.p.length/3||g.uv.length/2!==g.p.length/3||g.i.length%3!==0)throw Error("attributes");
   if(g.i.some(i=>i<0||i>=g.p.length/3||!Number.isInteger(i)))throw Error("index");
   for(let i=0;i<g.p.length;i+=3){if(!g.p.slice(i,i+3).every(Number.isFinite)||Math.abs(Math.hypot(...g.n.slice(i,i+3))-1)>1e-6)throw Error("normal or vertex");}
   for(let i=0;i<g.i.length;i+=3){const a=g.p.slice(g.i[i]*3,g.i[i]*3+3),b=g.p.slice(g.i[i+1]*3,g.i[i+1]*3+3),c=g.p.slice(g.i[i+2]*3,g.i[i+2]*3+3);if(Math.hypot(...cross(sub(b,a),sub(c,a)))<1e-10)throw Error("degenerate triangle");}
 }
 // Confirm the actual triangulated grid samples—not merely the analytic depression.
 const meshDepths=prints.map(h=>{
   const z=h.z,k=Math.min(2,Math.floor(z/12)),row=Math.floor((z-k*12)/dz),t=(z-k*12)/dz-row;
   let col=0;while(col<us.length-2&&us[col+1]<h.u)col++;let q=(h.u-us[col])/(us[col+1]-us[col]);
   const za=k*12+row*dz,zb=za+dz;
   const a=hoof(us[col],za).d,b=hoof(us[col+1],za).d,c=hoof(us[col],zb).d,d=hoof(us[col+1],zb).d;
   return q>=t?a+(b-a)*q+(d-b)*t:a+(c-a)*t+(d-c)*q;
 });
 if(Math.min(...meshDepths)<.008)throw Error("hoof geometry underresolved");
 const sampleDepths=prints.map(h=>hoof(h.u,h.z).d);if(Math.min(...sampleDepths)<.023||stats.roadGrass<1||stats.grassMax<.4||stats.stoneMax<.07)throw Error("detail requirement");
 let maxGrade=0;for(let j=1;j<360;j++){let z=j*.1;maxGrade=Math.max(maxGrade,Math.abs(height(0,z+.1)-height(0,z))/.1)}
 stats.path={length_m:36,nominal_meadow_width_m:20,grid_columns:nu,grid_rows_per_chunk:nz+1,half_width_min:Math.min(...Array.from({length:361},(_,j)=>half(j*.1))),half_width_max:Math.max(...Array.from({length:361},(_,j)=>half(j*.1))),curve_span:Math.max(...Array.from({length:361},(_,j)=>center(j*.1)))-Math.min(...Array.from({length:361},(_,j)=>center(j*.1))),hoof_count:prints.length,hoof_depth_min:Math.min(...sampleDepths),hoof_depth_max:Math.max(...sampleDepths),mesh_hoof_depth_min:Math.min(...meshDepths),mesh_hoof_depth_max:Math.max(...meshDepths),max_centerline_grade:maxGrade};
 stats.prototypeTriangles=Object.fromEntries([...grasses,...rocks].map(g=>[g.name,g.i.length/3]));stats.terrainTriangles=grounds.reduce((s,g)=>s+g.i.length/3,0);
 // Non-colliding continuous 3D hills around the exact playable core.
 function outerHeight(u,z){
   const distance=Math.hypot(Math.max(0,Math.abs(u)-10),Math.max(0,-z,z-36)),t=smooth(0,14,distance),x=center(z)+u;
   const broad=1.7*Math.sin(x*.041+z*.038)+2.3*Math.sin(z*.049+.55)+1.1*Math.sin(x*.078-z*.063)+.65*(noise(x*.11,z*.11,67)-.5);
   const ridge=6.2*Math.exp(-Math.pow((z-102)/35,2))*(.65+.35*Math.sin(x*.058+.7))+3.4*Math.exp(-Math.pow((x-40)/19,2)-Math.pow((z-54)/34,2));
   return mix(height(u,z),broad+ridge,t);
 }
 function outerColor(u,z){
   const distance=Math.hypot(Math.max(0,Math.abs(u)-10),Math.max(0,-z,z-36)),t=smooth(0,18,distance),x=center(z)+u;
   const a=noise(x*.16,z*.15,81),b=noise(x*.45,z*.39,82),field=[mix(.12,.22,a),mix(.16,.27,a),mix(.052,.10,a)].map(c=>c*(.89+.22*b));
   const m=road(u,z)*(1-smooth(107,150,z)),far=field.map((v,i)=>mix(v,[.32,.253,.17][i]*(.86+.29*b),m)),near=shade(u,z);
   return [...far.map((v,i)=>mix(near[i],v,t)),mix(near[3],m,t)];
 }
 const west=[-78,-68,-58,-48,-40,-32,-25,-20,-16,-13,-11.5,-10.5,-10],east=west.map(x=>-x).reverse();
 const innerZ=Array.from({length:361},(_,i)=>i*.1),allU=[...west.slice(0,-1),...us,...east.slice(1)];
 const back=[-65,-55,-45,-35,-26,-18,-12,-8,-5,-3,-2,-1,-.5,0],front=[36,36.5,37,38,39,41,43,46,50,55,60,65,70,75,80,85,90,95,100,105,110,115,120,130,140,150,165];
 const hinterland=[];
 function outerMesh(name,uu,zz){
   const g=mesh(name,0),e=.012;
   for(const z of zz)for(const u of uu){
     const x=center(z)+u,n=unit([-(outerHeight(u+e,z)-outerHeight(u-e,z))/(2*e),1,-(outerHeight(x-center(z+e),z+e)-outerHeight(x-center(z-e),z-e))/(2*e)]);
     vert(g,[x,outerHeight(u,z),z],n,outerColor(u,z),[x,z]);
   }
   for(let j=0;j<zz.length-1;j++)for(let i=0;i<uu.length-1;i++){const a=j*uu.length+i,b=a+1,c=a+uu.length,d=c+1;g.i.push(a,c,d,a,d,b)}
   hinterland.push(g);return g;
 }
 const left=outerMesh("CountryFarWest",west,innerZ),right=outerMesh("CountryFarEast",east,innerZ),south=outerMesh("CountryFarSouth",allU,back),north=outerMesh("CountryFarNorth",allU,front);
 // Weld the authored near border exactly: positions must agree before copying
 // existing normals and vertex colors. Adjacent exterior meshes share those values.
 function weld(a,ai,b,bi){
   for(let c=0;c<3;c++){if(Math.abs(a.p[ai*3+c]-b.p[bi*3+c])>1e-6)throw Error("extension position seam "+a.name+" "+b.name);a.p[ai*3+c]=b.p[bi*3+c];a.n[ai*3+c]=b.n[bi*3+c]}
   for(let c=0;c<4;c++)a.c[ai*4+c]=b.c[bi*4+c];
 }
 for(let j=0;j<innerZ.length;j++){
   const k=Math.min(2,Math.floor(j/120)),row=j-k*120;
   weld(left,j*west.length+west.length-1,grounds[k],row*nu);
   weld(right,j*east.length,grounds[k],row*nu+nu-1);
 }
 const shift=west.length-1,sw=(back.length-1)*allU.length;
 for(let i=0;i<us.length;i++){weld(south,sw+shift+i,grounds[0],i);weld(north,shift+i,grounds[2],nz*nu+i)}
 for(let i=0;i<west.length;i++){weld(south,sw+i,left,i);weld(north,i,left,(innerZ.length-1)*west.length+i)}
 for(let i=0;i<east.length;i++){let q=shift+us.length-1+i;weld(south,sw+q,right,i);weld(north,q,right,(innerZ.length-1)*east.length+i)}
 for(const g of hinterland){
   if(g.p.length!==g.n.length||g.c.length!==g.p.length/3*4||g.i.length%3)throw Error("outer attributes");
   for(let i=0;i<g.p.length;i+=3)if(!g.p.slice(i,i+3).every(Number.isFinite)||Math.abs(Math.hypot(...g.n.slice(i,i+3))-1)>1e-6)throw Error("outer normal");
   for(let i=0;i<g.i.length;i+=3){const a=g.p.slice(g.i[i]*3,g.i[i]*3+3),b=g.p.slice(g.i[i+1]*3,g.i[i+1]*3+3),c=g.p.slice(g.i[i+2]*3,g.i[i+2]*3+3);if(Math.hypot(...cross(sub(b,a),sub(c,a)))<1e-10)throw Error("outer degenerate");}
 }
 const trees=[];
 for(let zi=0;zi<20;zi++)for(let xi=0;xi<19;xi++){
   const z=-34+(zi+hash(xi,zi,182))*8.2,u=-66+(xi+hash(xi,zi,183))*7;
   if((z>=-2&&z<=38&&Math.abs(u)<12.7)||Math.abs(u)<4.6||hash(xi,zi,184)>.24+.16*noise(u*.12,z*.10,186))continue;
   const species=hash(xi,zi,187)<.55?"field_elm":hash(xi,zi,188)<.76?"cypress":"laurel",scale=(species==="laurel"?.70:.62)+.64*hash(xi,zi,189);
   let g,uu,zz;if(z<0){g=south;uu=allU;zz=back}else if(z>36){g=north;uu=allU;zz=front}else if(u< -10){g=left;uu=west;zz=innerZ}else if(u>10){g=right;uu=east;zz=innerZ}else continue;
   let i=0,j=0;while(i<uu.length-2&&uu[i+1]<u)i++;while(j<zz.length-2&&zz[j+1]<z)j++;
   if(u<uu[0]||u>uu.at(-1)||z<zz[0]||z>zz.at(-1))continue;
   const q=(u-uu[i])/(uu[i+1]-uu[i]),t=(z-zz[j])/(zz[j+1]-zz[j]),a=j*uu.length+i,b=a+1,c=a+uu.length,d=c+1;
   const h=q>=t?g.p[a*3+1]+(g.p[b*3+1]-g.p[a*3+1])*q+(g.p[d*3+1]-g.p[b*3+1])*t:g.p[a*3+1]+(g.p[c*3+1]-g.p[a*3+1])*t+(g.p[d*3+1]-g.p[c*3+1])*q;
   trees.push({species,x:round(mix(center(zz[j]),center(zz[j+1]),t)+u),y:round(h-.04),z:round(z),yaw:round(hash(xi,zi,190)*TAU),scale:round(scale)});
 }
 stats.hinterland={width_m:156,z_min:-65,z_max:165,triangles:hinterland.reduce((a,g)=>a+g.i.length/3,0),trees:trees.length,inner_edges_verified:true,scope:"visual continuation, no additional collision"};
 const probes=[2,6,10,12,16,22,24,28,34].map(z=>{let k=Math.min(2,Math.floor(z/12));return gridAt(k,0,z).map(round)});
 return {grounds,library:[...grasses,...rocks],scatter,stats,probes,prints,hinterland,trees};
}
function glb(meshes){
 const chunks=[],views=[],accessors=[],meshDefs=[],nodes=[];let offset=0;
 function attribute(array,comp,type,target){
   const width={SCALAR:1,VEC2:2,VEC3:3,VEC4:4}[type],data=comp===5126?new Float32Array(array):new Uint32Array(array),bytes=new Uint8Array(data.buffer),view=views.length;
   views.push({buffer:0,byteOffset:offset,byteLength:bytes.length,target});chunks.push(bytes);offset+=bytes.length;const acc={bufferView:view,componentType:comp,count:array.length/width,type};
   if(type==="VEC3"&&target===34962){acc.min=[Infinity,Infinity,Infinity];acc.max=[-Infinity,-Infinity,-Infinity];for(let i=0;i<data.length;i+=3)for(let k=0;k<3;k++){acc.min[k]=Math.min(acc.min[k],data[i+k]);acc.max[k]=Math.max(acc.max[k],data[i+k])}}
   accessors.push(acc);return accessors.length-1;
 }
 for(const g of meshes){const idx=meshDefs.length;meshDefs.push({name:g.name,primitives:[{attributes:{POSITION:attribute(g.p,5126,"VEC3",34962),NORMAL:attribute(g.n,5126,"VEC3",34962),TEXCOORD_0:attribute(g.uv,5126,"VEC2",34962),COLOR_0:attribute(g.c,5126,"VEC4",34962)},indices:attribute(g.i,5125,"SCALAR",34963),material:g.mat,mode:4}]});nodes.push({name:g.name,mesh:idx})}
 const materials=[{name:"Country_soil",rough:.93},{name:"Country_blades",rough:.87},{name:"Country_gravel",rough:.82}].map(m=>({name:m.name,pbrMetallicRoughness:{baseColorFactor:[1,1,1,1],metallicFactor:0,roughnessFactor:m.rough},doubleSided:true}));
 const doc={asset:{version:"2.0",generator:"IMPERATHEN VIVA ROMA country road original geometry"},scene:0,scenes:[{nodes:nodes.map((_,i)=>i)}],nodes,meshes:meshDefs,materials,buffers:[{byteLength:offset}],bufferViews:views,accessors,extras:{units:"metres",coordinate:"Y up",source:"deterministic original geometry, no external art"}};
 const raw=JSON.stringify(doc),json=new Uint8Array(Math.ceil(raw.length/4)*4);json.fill(32);for(let i=0;i<raw.length;i++)json[i]=raw.charCodeAt(i);
 const out=new Uint8Array(28+json.length+offset),d=new DataView(out.buffer);d.setUint32(0,0x46546c67,true);d.setUint32(4,2,true);d.setUint32(8,out.length,true);d.setUint32(12,json.length,true);d.setUint32(16,0x4e4f534a,true);out.set(json,20);let pos=20+json.length;d.setUint32(pos,offset,true);d.setUint32(pos+4,0x004e4942,true);pos+=8;for(const c of chunks){out.set(c,pos);pos+=c.length}return out;
}
// END GENERATOR CORE
const out=resolve(process.argv[2]||"prototype/assets/viva_country");mkdirSync(out,{recursive:true});const a=generate();for(let i=0;i<3;i++){writeFileSync(resolve(out,"terrain_"+i+".glb"),glb([a.grounds[i]]));writeFileSync(resolve(out,"scatter_"+i+".json"),JSON.stringify(a.scatter[i])+"\n");}writeFileSync(resolve(out,"scatter_library.glb"),glb(a.library));writeFileSync(resolve(out,"hinterland.glb"),glb(a.hinterland));writeFileSync(resolve(out,"hinterland_trees.json"),JSON.stringify({schema:1,trees:a.trees},null,2)+"\n");writeFileSync(resolve(out,"manifest.json"),JSON.stringify({schema:1,stats:a.stats,probes:a.probes,hoofprints:a.prints,scope:"3D country road reference, not integrated into campaign"},null,2)+"\n");console.log(JSON.stringify(a.stats,null,2));
