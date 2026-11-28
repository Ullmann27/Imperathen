#!/usr/bin/env node
// Declaration-only lexical inventory. Not a GDScript compiler or API checker.
import { execFileSync } from "node:child_process";
import { readFileSync,writeFileSync,existsSync } from "node:fs";
import { join,resolve } from "node:path";
import { pathToFileURL } from "node:url";

function lex(source) {
  let quote = "", triple = false;
  return source.replace(/\r\n/g, "\n").replace(/^\uFEFF/,"").split("\n").map(line => {
    let code = "", mask = "";
    for (let i=0;i<line.length;i++) {
      const c=line[i];
      if (quote) {
        if (c==="\\") {
          code+=c; mask+=" ";
          if (i+1<line.length) { code+=line[++i]; mask+=" "; }
        } else if (triple && line.slice(i,i+3)===quote.repeat(3)) {
          code+=line.slice(i,i+3); mask+="   "; i+=2; quote=""; triple=false;
        } else if (!triple && c===quote) {
          code+=c; mask+=" "; quote="";
        } else {code+=c;mask+=" ";}
      } else if(c==="#") break;
      else if(c==="\""||c==="'") {
        quote=c;triple=line.slice(i,i+3)===c.repeat(3);
        if(triple){code+=line.slice(i,i+3);mask+="   ";i+=2;}
        else{code+=c;mask+=" ";}
      } else {code+=c;mask+=c;}
    }
    if(quote&&!triple&&!line.endsWith("\\"))quote="";
    return {code,mask};
  });
}

function stripAnnotations(row) {
  const offset=row.mask.match(/^\s*/)[0].length;
  let code=row.code.slice(offset),mask=row.mask.slice(offset);
  while(mask.startsWith("@")) {
    const m=/^@[A-Za-z_]\w*/.exec(mask);
    if(!m)break;
    let end=m[0].length;
    while(mask[end]===" "||mask[end]==="\t")end++;
    if(mask[end]==="("){
      let depth=0, found=false;
      for(let i=end;i<mask.length;i++){
        if(mask[i]==="(")depth++;
        else if(mask[i]===")"&&--depth===0){end=i+1;found=true;break;}
      }
      if(!found)return {code:"",mask:""};
    }
    code=code.slice(end);mask=mask.slice(end);
    const skip=mask.match(/^\s*/)[0].length;code=code.slice(skip);mask=mask.slice(skip);
  }
  return {code,mask};
}

function signature(rows,start,first,kind,path) {
  let depth=0, seenParen=false, parts=[];
  for(let n=start;n<rows.length;n++){
    const row=n===start?first:rows[n];
    const mask=row.mask, code=row.code;
    let end=mask.length, complete=false;
    for(let i=0;i<mask.length;i++){
      const c=mask[i];
      if(c==="("){depth++;seenParen=true;}
      else if(c==="["||c==="{")depth++;
      else if(c===")"||c==="]"||c==="}")depth--;
      else if(c===":"&&depth===0&&kind==="func"&&seenParen){end=i;complete=true;break;}
      if(depth<0)throw Error(`${path}:${start+1}: unbalanced declaration`);
    }
    const piece=code.slice(0,end).trim().replace(/\\$/,"").trim();
    if(piece)parts.push(piece);
    if(kind==="signal"&&depth===0)complete=true;
    if(complete)return {value:parts.join(" "),end:n};
  }
  throw Error(`${path}:${start+1}: unfinished ${kind} declaration`);
}

function parseScript(source,path) {
  const rows=lex(source), result=[], stack=[{headerIndent:-1,memberIndent:0,name:""}];
  for(let i=0;i<rows.length;i++){
    const row=rows[i];if(!row.mask.trim())continue;
    const indent=row.mask.match(/^[ \t]*/)[0].replace(/\t/g,"    ").length;
    while(stack.length>1&&indent<=stack.at(-1).headerIndent)stack.pop();
    const scope=stack.at(-1);
    if(scope.memberIndent===null)scope.memberIndent=indent;
    if(indent!==scope.memberIndent)continue;
    const stripped=stripAnnotations(row);
    const m=stripped.mask.trim();
    const add=(value)=>result.push({scope:scope.name,value});
    if(/^class_name\s+\w+/.test(m)||/^extends(?:\s|$)/.test(m)){add(stripped.code.trim());continue;}
    const innerName=/^class\s+([A-Za-z_]\w*)\b.*:\s*$/.exec(m)?.[1];
    if(innerName){add(stripped.code.trim().slice(0,-1).trim());stack.push({headerIndent:indent,memberIndent:null,name:scope.name?scope.name+"."+innerName:innerName});continue;}
    const fn=/^(?:static\s+)?func\s+([A-Za-z_]\w*)\s*\(/.exec(m);
    if(fn){const s=signature(rows,i,stripped,"func",path);i=s.end;if(!fn[1].startsWith("_"))add(s.value);continue;}
    if(/^signal\s+[A-Za-z_]\w*/.test(m)){const s=signature(rows,i,stripped,"signal",path);i=s.end;add(s.value);}
  }
  return result;
}

function isRuntime(path) {return /^prototype\/scripts\/.+\.gd$/.test(path)&&!path.startsWith("prototype/scripts/tests/");}

function autoloads(project) {
  let active=false, result=[];
  for(const raw of project.replace(/\r\n/g,"\n").split("\n")){
    let line=raw.trim();
    if(/^\[.*\]$/.test(line)){active=line==="[autoload]";continue;}
    if(active&&/^[A-Za-z_]\w*\s*=/.test(line))result.push(line);
  }
  return result.sort();
}

function inlineCode(value) {
  const runs=value.match(/`+/g)??[];
  const fence="`".repeat(Math.max(0,...runs.map(s=>s.length))+1);
  return fence+(value.startsWith("`")?" ":"")+value+(value.endsWith("`")?" ":"")+fence;
}

function buildIndex(scripts,project) {
  const names=Object.keys(scripts).filter(isRuntime).sort();
  const lines=["# ARCHITEKTUR_INDEX","","## Autoloads","",...autoloads(project).map(s=>"- "+inlineCode(s))];
  for(const path of names){
    lines.push("","## "+path,"");
    const declarations=parseScript(scripts[path],path);
    for(const decl of declarations)lines.push("- "+(decl.scope?inlineCode(decl.scope)+": ":"")+inlineCode(decl.value));
  }
  return lines.join("\n")+"\n";
}

export { lex,stripAnnotations,signature,parseScript,isRuntime,autoloads,inlineCode,buildIndex };

function main() {
  const args=process.argv.slice(2);
  if(args.some(arg=>arg!=="--check")||args.length>1)throw Error("Usage: node tools/architecture/build_index.mjs [--check]");
  const root=execFileSync("git",["rev-parse","--show-toplevel"],{encoding:"utf8"}).trim();
  const files=execFileSync("git",["ls-files","--cached","-z"],{cwd:root,encoding:"utf8",maxBuffer:16*1024*1024}).split("\0").filter(isRuntime);
  const scripts=Object.fromEntries([...new Set(files)].map(path=>[path,readFileSync(join(root,path),"utf8")]));
  const content=buildIndex(scripts,readFileSync(join(root,"prototype/project.godot"),"utf8"));
  const destination=join(root,"ARCHITEKTUR_INDEX.md");
  if(args.includes("--check")){
    if(!existsSync(destination)||readFileSync(destination,"utf8")!==content){
      console.error("Architecture index stale. Stage new runtime files, regenerate and stage ARCHITEKTUR_INDEX.md.");
      process.exitCode=1;return;
    }
  } else writeFileSync(destination,content,"utf8");
  console.log("Architecture index: "+Object.keys(scripts).length+" runtime scripts; "+(args.includes("--check")?"verified":"generated"));
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href)main();
