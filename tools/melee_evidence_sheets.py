#!/usr/bin/env python3
"""Contact sheets for the level-A melee evidence (D-038).

Usage: melee_evidence_sheets.py <render dir> <output dir>
<render dir> is what prototype/tests/melee_evidence_render.gd wrote
(MELEE_EVIDENCE_OUT): one folder per sequence with fNNN.png and meta.json.
Each sheet shows the saved frames in order with simulation frame, offset to
the centred event, clip frame, phase and the events booked on that frame.
"""
import json,glob,os,sys
from PIL import Image, ImageDraw, ImageFont
base=sys.argv[1]
out=sys.argv[2]
os.makedirs(out,exist_ok=True)
try:
    font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',15)
    big=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',20)
except Exception:
    font=big=ImageFont.load_default()
titles={'hit_weapon_side':'Gladius-Stoss von der Waffenseite (90°) gegen Rundschild-Deckung vorn -> Treffer',
 'block_front':'Gleicher Gladius-Stoss frontal gegen Rundschild-Deckung -> Block',
 'block_axe_on_scutum':'Axt-Überkopfhieb gegen Scutum-Hochdeckung -> Block (Holz/Bronzebuckel)',
 'scutum_edge_catches_flank':'Axt-Innenhieb von rechts (70°) gegen Frontdeckung: der 0,78 m breite Scutum faengt ihn an der Kante -> Block',
 'flank_hit_reaction':'Axt-Ueberkopfhieb von rechts hinten (105°) an der Frontdeckung vorbei -> Treffer + Reaktion',
 'youth_jab_on_raider':'12-Jaehriger: rechte Gerade (youth_unarmed, dieselben Spuren wie die Spieler-Autoritaet) gegen Axtkaempfer von dessen Waffenseite -> Treffer',
 'spear_reach_vs_axe':'Speerstoss (Schlachtrig, 2,15 m Reichweite) gegen Axtkaempfer von dessen Waffenseite -> Treffer',
 'dynamic_camera_block':'Dynamische Kampfkamera ueber der Schulter des Legionaers: Axt-Ueberkopfhieb in die Scutum-Hochdeckung, Kamerastoss am Kontaktframe',
 'before_legacy_hit_weapon_side':'VORHER (bisherige Darstellung, gleiche Kamera/Frames wie hit_weapon_side): Dienst-Gladius bleibt senkrecht, der berechnete Kontakt hat kein sichtbares Gegenstueck',
 'ai_duel_first_hit':'KI-Duell (beide ueber melee_ai.gd, Start 4 m Abstand): Annaeherung, Deckung, erster Treffer ueber den Rundschild, Reaktion',
 'ai_duel_guard_break_then_hit':'KI-Duell: Deckungsbruch reisst den Scutum aus der Linie, der Folgehieb trifft in die Oeffnung',
 'whiff_out_of_reach':'Axt-Überkopfhieb ausserhalb der Reichweite (auch vor dem Scutum) -> Fehlschlag, kein Schaden'}
for seq in sorted(d for d in os.listdir(base) if os.path.isdir(f'{base}/{d}')):
    meta=json.load(open(f'{base}/{seq}/meta.json'))
    frames={m['frame']:m for m in meta['frames']}
    files=sorted(glob.glob(f'{base}/{seq}/f*.png'))
    W,H=480,360; cols=4; rows=(len(files)+cols-1)//cols
    sheet=Image.new('RGB',(W*cols,H*rows+40),(20,20,20))
    d=ImageDraw.Draw(sheet)
    d.text((10,8),titles.get(seq,seq)+f'   (Kontakt-/Ereignisframe {meta["contact"]})',fill=(255,255,255),font=big)
    for i,f in enumerate(files):
        n=int(os.path.basename(f)[1:4])
        im=Image.open(f).convert('RGB').crop((120,60,840,600)).resize((W,H))
        x=(i%cols)*W; y=40+(i//cols)*H
        sheet.paste(im,(x,y))
        m=frames.get(n,{})
        rel=n-meta['contact']
        lab=f"Frame {n} ({rel:+d})  t={n/60:.3f}s  Clip {m.get('clip_frame','-')}  {m.get('phase','')}"
        ev=', '.join(m.get('events',[]))
        col=(255,215,80) if rel==0 else (235,235,235)
        d.rectangle((x,y,x+W,y+44),fill=(0,0,0))
        d.text((x+6,y+3),lab,fill=col,font=font)
        d.text((x+6,y+22),ev[:60] if ev else f"Verteidiger: {m.get('defender','')}",fill=(255,140,120) if ev else (180,180,180),font=font)
    sheet.save(f'{out}/{seq}.jpg',quality=86)
    print(seq, sheet.size, os.path.getsize(f'{out}/{seq}.jpg'))
