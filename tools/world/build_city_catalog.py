#!/usr/bin/env python3
"""Inventory real runtime GLBs for the independent city test."""
import json
import re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
ASSETS=ROOT/"prototype/assets"
OUTPUT=ASSETS/"world/city_catalog.json"
TIER=re.compile(r"_(?P<tier>[0-3]|near|mid|far|lod[0-3])$")
LABELS={"frontier_hut":"Grenzhütte","atrium_house":"Römisches Atriumhaus","frontier_house":"Wohnhaus","village_well":"Dorfbrunnen","workshop":"Werkstatt","training_dummy":"Übungspfahl","timber_billet":"Holzbündel","storehouse":"Speicher","market":"Marktstand","palisade_silhouette":"Palisadenreihe","palisade_bay":"Palisadensegment","oak":"Eiche","olive":"Olivenbaum","pine":"Kiefer","wood_longhouse":"Langhaus","wa_store":"Wa-Speicher","wa_house":"Wa-Haus","han_house":"Han-Haus","farmer":"Feldarbeiter","wa_farmer":"Wa-Feldarbeiter","han_farmer":"Han-Feldarbeiter","gladius":"Gladius","scutum":"Scutum","hero_quality":"Bisherige Hauptfigur","hero_meshy_italia":"Meshy-Jugendlicher","frontier_archer":"Bogenschütze","frontier_civilian_man":"Dorfbewohner","frontier_civilian_woman":"Dorfbewohnerin","frontier_elder":"Ältester","frontier_legionary":"Legionär","frontier_officer":"Offizier","frontier_spearman":"Speerträger","villager":"Frühe Dorffigur","unit_roman_signifer":"Römischer Signifer","unit_germanic_axe_fighter":"Germanischer Axtkämpfer","gear_germanic_round_shield":"Rundschild","gear_roman_signum":"Signum","weap_germanic_hand_axe":"Handaxt","heavy":"Schwerer Soldat","officer":"Offizier","spear":"Speerträger","archer":"Bogenschütze"}
def collect():
    families={}
    for path in sorted(ASSETS.rglob("*.glb")):
        relative=path.relative_to(ASSETS)
        if relative.parts[0]=="world" or "source" in relative.parts: continue
        match=TIER.search(path.stem)
        stem=path.stem[:match.start()] if match else path.stem
        identity=str(relative.parent/stem)
        raw=match.group("tier") if match else "0"
        level={"near":0,"mid":1,"far":3}.get(raw)
        if level is None: level=int(raw.removeprefix("lod"))
        category="equipment" if relative.parts[0]=="weapons" or "equipment" in relative.parts else "models"
        if relative.parts[0] in ("architecture","village") or "house" in stem or "hut" in stem: category="buildings"
        if stem in ("oak","olive","pine"): category="nature"
        entry=families.setdefault(identity,{"id":identity,"name":LABELS.get(stem,stem.replace("_"," ")),"category":category,"tiers":[]})
        entry["tiers"].append({"level":level,"path":"res://assets/"+relative.as_posix()})
    ordered=sorted(families.values(),key=lambda item:(item["category"],item["id"]))
    for entry in ordered: entry["tiers"].sort(key=lambda item:item["level"])
    return {"format":"imperathen-city-catalog","version":1,"source":"Existing runtime GLBs; one station per model family.","family_count":len(ordered),"binary_count":sum(len(item["tiers"]) for item in ordered),"families":ordered}
if __name__=="__main__":
    data=collect()
    OUTPUT.parent.mkdir(parents=True,exist_ok=True)
    OUTPUT.write_text(json.dumps(data,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
    print(json.dumps({"families":data["family_count"],"binaries":data["binary_count"]}))
