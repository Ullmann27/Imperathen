// Original procedural materials; deterministic, dependency-free core.
const specs=[
  {
    "id": "iron_worn",
    "family": "iron",
    "base": [
      132,
      128,
      119
    ],
    "wear": 0.88,
    "rough": 0.72,
    "metal": 0.95,
    "seed": 21
  },
  {
    "id": "iron_service",
    "family": "iron",
    "base": [
      151,
      153,
      155
    ],
    "wear": 0.36,
    "rough": 0.48,
    "metal": 0.96,
    "seed": 21
  },
  {
    "id": "iron_veteran",
    "family": "iron",
    "base": [
      167,
      169,
      171
    ],
    "wear": 0.56,
    "rough": 0.38,
    "metal": 0.97,
    "seed": 21
  },
  {
    "id": "iron_honor",
    "family": "iron",
    "base": [
      189,
      189,
      181
    ],
    "wear": 0.13,
    "rough": 0.27,
    "metal": 0.98,
    "seed": 21
  },
  {
    "id": "leather_oiled",
    "family": "leather",
    "base": [
      89,
      48,
      27
    ],
    "wear": 0.45,
    "rough": 0.62,
    "metal": 0,
    "seed": 53
  },
  {
    "id": "oak_worked",
    "family": "wood",
    "base": [
      132,
      86,
      47
    ],
    "wear": 0.5,
    "rough": 0.78,
    "metal": 0,
    "seed": 77
  },
  {
    "id": "lime_plaster",
    "family": "plaster",
    "base": [
      211,
      198,
      174
    ],
    "wear": 0.58,
    "rough": 0.88,
    "metal": 0,
    "seed": 91
  }
];
function generate(s,n){
 const clamp=(v,a=0,b=1)=>Math.max(a,Math.min(b,v)),lerp=(a,b,t)=>a+(b-a)*t,smooth=x=>x*x*(3-2*x),mod=(x,m)=>((x%m)+m)%m;
 const hash=(x,y,k)=>{let z=Math.imul(x+3571,374761393)^Math.imul(y+619,668265263)^Math.imul(k+1,1442695041);z=Math.imul(z^(z>>>13),1274126177);return ((z^(z>>>16))>>>0)/4294967295};
 function noise(u,v,gx,gy,k){let x=u*gx,y=v*gy,ix=Math.floor(x),iy=Math.floor(y),a=smooth(x-ix),b=smooth(y-iy);const h=(dx,dy)=>hash(mod(ix+dx,gx),mod(iy+dy,gy),s.seed+k);return lerp(lerp(h(0,0),h(1,0),a),lerp(h(0,1),h(1,1),a),b);}
 const count=n*n,height=new Float32Array(count),albedo=new Uint8Array(count*3),orm=new Uint8Array(count*3),normal=new Uint8Array(count*3);const byte=x=>Math.round(clamp(x,0,255));
 for(let y=0;y<n;y++)for(let x=0;x<n;x++){
 const u=x/n,v=y/n,i=y*n+x,k=i*3;
 const a=noise(u,v,5,5,1),b=noise(u,v,19,19,2),c=noise(u,v,64,64,3),d=noise(u,v,137,137,4);
 let h=0,lum=0,rough=s.rough,metal=s.metal,ao=1,tint=[0,0,0];
 if(s.family==="iron"){
 const brush=noise(u,v,12,113,7),pit=Math.pow(clamp((.27-c)*3.7),2),oxide=clamp((a*.57+b*.43-.53)*3.4)*s.wear;
 const line=Math.max(0,1-Math.abs(Math.sin(2*Math.PI*(u*7+v*3+.018*noise(u,v,9,9,9))))*19)*clamp((noise(u,v,8,8,11)-.42)*3)*s.wear;
 h=(b-.5)*.0011+(brush-.5)*.00055+(d-.5)*.00013-pit*.0014*s.wear-line*.0008;
 lum=(a-.5)*24+(b-.5)*12+(brush-.5)*11+line*34-pit*19;
 tint=[oxide*31,-oxide*13,-oxide*34];metal=lerp(s.metal,.08,oxide);rough=clamp(s.rough+(b-.5)*.19+oxide*.28-line*.13,.12,.97);ao=clamp(1-pit*.22*s.wear,.7,1);
 }else if(s.family==="leather"){
 const pore=clamp((.34-d)*3.2),grain=noise(u,v,91,109,7),crease=Math.pow(1-Math.abs(2*b-1),12);
 h=(a-.5)*.0015+(grain-.5)*.0012-pore*.0009-crease*.0007;lum=(a-.5)*30+(grain-.5)*21-pore*14;rough=clamp(s.rough+(b-.5)*.23+pore*.09,.4,.95);ao=1-pore*.18;
 }else if(s.family==="wood"){
 const warp=noise(u,v,5,3,11),grain=Math.sin(2*Math.PI*(u*36+warp*.55)),fiber=noise(u,v,118,6,9),dark=Math.pow(Math.max(0,-grain),7);
 h=grain*.0007+(fiber-.5)*.0008-dark*.0007+(b-.5)*.0005;lum=grain*13+(fiber-.5)*19-dark*31+(a-.5)*25;rough=clamp(s.rough+(fiber-.5)*.16+dark*.08,.55,.98);ao=1-dark*.13;
 }else{
 const pit=clamp((.31-d)*3.3),mottle=a*.65+b*.35;h=(b-.5)*.0021+(c-.5)*.0013-pit*.0012;lum=(mottle-.5)*49+(d-.5)*13-pit*18;rough=clamp(s.rough+(c-.5)*.16,.62,.99);ao=1-pit*.18;
 }
 height[i]=h;for(let j=0;j<3;j++)albedo[k+j]=byte(s.base[j]+lum+tint[j]);orm[k]=byte(ao*255);orm[k+1]=byte(rough*255);orm[k+2]=byte(metal*255);
 }
 for(let y=0;y<n;y++)for(let x=0;x<n;x++){const i=(y*n+x)*3,dx=(height[y*n+mod(x+1,n)]-height[y*n+mod(x-1,n)])*n*.5,dy=(height[mod(y+1,n)*n+x]-height[mod(y-1,n)*n+x])*n*.5;const l=Math.hypot(dx,dy,1);normal[i]=byte((-.5*dx/l+.5)*255);normal[i+1]=byte((.5*dy/l+.5)*255);normal[i+2]=byte((.5/l+.5)*255);}
 return {basecolor:albedo,normal,orm};
}
function png(rgb,n){
 const be=x=>[(x>>>24)&255,(x>>>16)&255,(x>>>8)&255,x&255];
 const crcTable=Array.from({length:256},(_,i)=>{for(let j=0;j<8;j++)i=(i&1)?(0xedb88320^(i>>>1)):(i>>>1);return i>>>0});
 const crc=bytes=>{let c=0xffffffff;for(const b of bytes)c=crcTable[(c^b)&255]^(c>>>8);return (c^0xffffffff)>>>0};
 const raw=new Uint8Array(n*(n*3+1));for(let y=0;y<n;y++)raw.set(rgb.subarray(y*n*3,(y+1)*n*3),y*(n*3+1)+1);
 let ad1=1,ad2=0;for(const b of raw){ad1=(ad1+b)%65521;ad2=(ad2+ad1)%65521}
 const blocks=[Uint8Array.of(0x78,0x01)];for(let i=0;i<raw.length;i+=65535){let l=Math.min(65535,raw.length-i),q=(~l)&65535;blocks.push(Uint8Array.of(i+l===raw.length?1:0,l&255,l>>>8,q&255,q>>>8),raw.subarray(i,i+l));}blocks.push(Uint8Array.from(be((ad2<<16)|ad1)));
 const cat=parts=>{const out=new Uint8Array(parts.reduce((a,b)=>a+b.length,0));let p=0;for(const b of parts){out.set(b,p);p+=b.length}return out};
 const chunk=(name,data)=>{const body=cat([Uint8Array.from([...name].map(c=>c.charCodeAt(0))),data]);return cat([Uint8Array.from(be(data.length)),body,Uint8Array.from(be(crc(body)))])};
 return cat([Uint8Array.of(137,80,78,71,13,10,26,10),chunk("IHDR",Uint8Array.from([...be(n),...be(n),8,2,0,0,0])),chunk("IDAT",cat(blocks)),chunk("IEND",new Uint8Array(0))]);
}
function validate(m,n,s){
 const len=n*n*3;let rough=0,metal=0,err=0,lo=255,hi=0;for(const a of Object.values(m))if(a.length!==len)throw Error("map size");
 for(let i=0;i<len;i+=3){let x=m.normal[i]/127.5-1,y=m.normal[i+1]/127.5-1,z=m.normal[i+2]/127.5-1;err=Math.max(err,Math.abs(Math.hypot(x,y,z)-1));if(z<0)throw Error("normal flipped");rough+=m.orm[i+1];metal+=m.orm[i+2];lo=Math.min(lo,m.basecolor[i]);hi=Math.max(hi,m.basecolor[i]);}
 if(err>.012||hi-lo<7||(!s.metal&&metal!==0))throw Error("material statistics");
 return {mean_roughness:+(rough/(n*n*255)).toFixed(4),mean_metallic:+(metal/(n*n*255)).toFixed(4),max_normal_length_error:+err.toFixed(5),red_range:[lo,hi]};
}

// END CORE
export {specs,generate,png,validate};
