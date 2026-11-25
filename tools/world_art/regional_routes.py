#!/usr/bin/env python3
"""Validate and query the authored regional trade-route graph.

This is route geometry/data, not a second economy or caravan simulation.
"""
from __future__ import annotations
import argparse
import heapq
import json
import math
from pathlib import Path

def finite_point(value):
    return (isinstance(value,list) and len(value)==2
            and all(type(x) in (float,int) and math.isfinite(x) for x in value))

def route_length(points):
    return sum(math.dist(a,b) for a,b in zip(points,points[1:]))

def validate_atlas(manifest):
    settlements = {row["id"]:row for row in manifest["settlements"]}
    regions = manifest["regions"]
    ids = [row["id"] for row in regions]
    if len(set(ids)) != len(ids) or not ids:
        raise ValueError("Region ids must be nonempty and unique")
    by_id = {row["id"]:row for row in regions}
    graph = {identity:[] for identity in ids}
    routes = {}
    for region in regions:
        if region["settlement"] not in settlements or not finite_point(region["position"]):
            raise ValueError("Invalid region configuration")
    for route in manifest["trade_routes"]:
        identity = route["id"]
        if not identity or identity in routes or route["from"] == route["to"]:
            raise ValueError("Invalid or duplicate route identity")
        a,b = route["from"],route["to"]
        if a not in graph or b not in graph:
            raise ValueError("Unknown route endpoint")
        points=route["waypoints"]
        if len(points)<2 or not all(finite_point(p) for p in points):
            raise ValueError("Invalid route geometry")
        if points[0]!=by_id[a]["position"] or points[-1]!=by_id[b]["position"]:
            raise ValueError("Route does not meet both settlement anchors")
        length=route_length(points)
        if length <= 0 or any(math.dist(x,y)<.001 for x,y in zip(points,points[1:])):
            raise ValueError("Zero-length route segment")
        if not route.get("goods") or len(set(route["goods"]))!=len(route["goods"]):
            raise ValueError("Route goods must be nonempty and unique")
        graph[a].append((b,identity,length)); graph[b].append((a,identity,length))
        routes[identity]={"length_m":length,"from":a,"to":b}
    reached={ids[0]}; pending=[ids[0]]
    while pending:
        for other,_,_ in graph[pending.pop()]:
            if other not in reached:
                reached.add(other); pending.append(other)
    if reached != set(ids):
        raise ValueError("Regional trade network is disconnected")
    return graph,routes

def shortest_route(manifest,start,destination,closed_routes=()):
    graph,_=validate_atlas(manifest)
    if start not in graph or destination not in graph:
        raise ValueError("Unknown settlement")
    closed=set(closed_routes)
    frontier=[(0.0,start,())]; best={start:0.0}
    while frontier:
        distance,current,path=heapq.heappop(frontier)
        if distance>best[current]:
            continue
        if current==destination:
            return {"reachable":True,"length_m":distance,"routes":list(path)}
        for other,identity,length in graph[current]:
            next_distance=distance+length
            if identity not in closed and next_distance<best.get(other,float("inf")):
                best[other]=next_distance
                heapq.heappush(frontier,(next_distance,other,path+(identity,)))
    return {"reachable":False,"length_m":None,"routes":[]}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest",type=Path,default=Path(__file__).resolve().parents[2]/"prototype/assets/world_expansion/manifest.json")
    parser.add_argument("--output",type=Path)
    args=parser.parse_args()
    manifest=json.loads(args.manifest.read_text())
    graph,routes=validate_atlas(manifest)
    sizes={s["id"]:s["count"] for s in manifest["settlements"]}
    result={"status":"passed","regions":len(graph),"routes":routes,
            "planned_building_placements":sum(sizes[r["settlement"]] for r in manifest["regions"]),
            "scope":"Layout/route graph only; no inhabitants, active trade or historical city reconstruction",
            "west_to_east":shortest_route(manifest,"capital_west","capital_east")}
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result,indent=2))

if __name__=="__main__":
    main()
