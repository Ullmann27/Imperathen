#!/usr/bin/env node
import * as api from "./build_index.mjs";

function runFixtureTests(api) {
  const checks=[];
  function eq(a,b,label){if(JSON.stringify(a)!==JSON.stringify(b))throw Error(label+"\nactual: "+JSON.stringify(a)+"\nexpected: "+JSON.stringify(b));checks.push(label);}
  const fixture=[
    "class_name Probe","extends Node","signal changed","signal named(id: String,",
    "\tdata: Dictionary = {\"a\": [1, 2]})",
    "func read(","\tkey: String = \"# : ()\","," \toptions: Dictionary = {\"nested\": [1, 2]}",") -> Dictionary: # comment",
    "\treturn options","static func _hidden() -> void:"," \treturn",
    "func one_line() -> int: return 1",
    "@rpc(\"authority\", \"call_remote\") func remote(value: String) -> void:","\tprint(value)",
    "class Nested extends RefCounted:","\tsignal fired","\tfunc run(value: int) -> bool:","\t\treturn value > 0",
    "\tclass Deep:","\t\textends Node","\t\tfunc get_id() -> int:","\t\t\treturn 1",
    "func after() -> void:","\tvar fake := \"\"\"","func injected() -> void:","class Fake:","\"\"\"",
    "\tprint(fake)","func last() -> String: return \"ok\""
  ].join("\n");
  eq(api.parseScript(fixture,"fixture.gd").map(y=>[y.scope,y.value]),[
    ["","class_name Probe"],["","extends Node"],["","signal changed"],["","signal named(id: String, data: Dictionary = {\"a\": [1, 2]})"],
    ["","func read( key: String = \"# : ()\", options: Dictionary = {\"nested\": [1, 2]} ) -> Dictionary"],
    ["","func one_line() -> int"],["","func remote(value: String) -> void"],["","class Nested extends RefCounted"],
    ["Nested","signal fired"],["Nested","func run(value: int) -> bool"],["Nested","class Deep"],["Nested.Deep","extends Node"],["Nested.Deep","func get_id() -> int"],["","func after() -> void"],["","func last() -> String"]
  ],"multiline declarations, private callbacks, annotation, nested classes, inline body, strings");
  eq(api.parseScript('extends "res://base.gd"\nclass Child extends "res://x.gd":\n    func f() -> void:\n        return\n',"quoted.gd").map(x=>[x.scope,x.value]),[["",'extends "res://base.gd"'],["",'class Child extends "res://x.gd"'],["Child","func f() -> void"]],"quoted base types");
  eq(api.autoloads('[application]\nname="Game"\n[autoload]\nWorld="*res://world.gd"\n; ignored\nClock="res://clock.gd"\n[rendering]\nquality=1'),['Clock="res://clock.gd"','World="*res://world.gd"'],"actual autoload section only");
  eq(api.isRuntime("prototype/scripts/world/foo.gd"),true,"runtime inclusion");
  eq(api.isRuntime("prototype/scripts/tests/foo.gd"),false,"test-only exclusion");
  eq(api.isRuntime("prototype/tests/foo.gd"),false,"regression exclusion");
  eq(api.isRuntime("prototype/scripts/foo.gd.uid"),false,"uid exclusion");
  eq(api.isRuntime("prototype/.godot/foo.gd"),false,"cache exclusion");
  const scripts={"prototype/scripts/b.gd":"extends Node\nfunc b() -> void:\n\treturn\n","prototype/scripts/a.gd":"extends Node\nsignal a\n","prototype/tests/z.gd":"extends Node"};
  eq(api.buildIndex(scripts,"[autoload]\nClock=\"*res://clock.gd\"\n"),api.buildIndex(Object.fromEntries(Object.entries(scripts).reverse()),"[autoload]\nClock=\"*res://clock.gd\"\n"),"deterministic ordering");
  eq(api.buildIndex(scripts,"").includes("prototype/tests/z.gd"),false,"no test declarations in index");
  eq(api.buildIndex(scripts,"").includes("func b() -> void`"),true,"signature without body");
  eq(api.inlineCode("a`b"),"``a`b``","Markdown code fence safety");
  eq(api.parseScript("\uFEFFextends Node\r\nfunc get_value() -> int:\r\n\treturn 1\r\n","bom.gd").map(x=>x.value),["extends Node","func get_value() -> int"],"BOM and CRLF");
  let rejected=false;try{api.parseScript("func broken(x: int\n","broken.gd")}catch{rejected=true;}eq(rejected,true,"incomplete signature fails closed");
  return checks;
}
const checks=runFixtureTests(api);
for(const label of checks)console.log("PASS "+label);
console.log("ARCHITECTURE_INDEX_TEST_RESULT checks="+checks.length+" failures=0");
