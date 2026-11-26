"""Species growth parameters for the Valdora vegetation (Aquileia region, 58 BC).

Heights, crown radii and branch habits follow common forestry descriptions of
mature open-grown or hedgerow trees in the north Italian lowland. They are
design values for game silhouettes, not measured specimens. See
docs/vegetation/ARTENLISTE_VALDORA_58VC.md for the species choice and sources.

Envelope shapes (crown radius as a function of relative crown height):
  dome     broad, flattened (oak in the open)
  ovoid    egg-shaped (hornbeam, ash, field maple)
  vase     narrow base, wide top (field elm)
  column   tall and narrow-ish (black poplar)
  cone     conical (black alder)
  ball     round head (pollards, hawthorn)
  fountain wide, arching, open (willow, hazel, elder)
"""

TREES = {
    "quercus_robur": dict(
        seed=7101, bark="oak", leaf="oak", height=17.0, crown_base=.30, radius=7.2, envelope="dome",
        trunk_radius=.42, taper=.62, lean=.05, wander=.10, flare=.55, flare_roots=7, flute=.0, burl=.10,
        n1=11, angle1=(66, 42), tropism1=-.04, wander1=.24, reach1=1.0, kink1=.35,
        n2=6, angle2=55, ratio2=.55, tropism2=.02, wander2=.28,
        n3=4, angle3=50, ratio3=.45, card=.62, cards_per_m=3.2, leader=.55),
    "quercus_cerris": dict(
        seed=7103, bark="cerris", leaf="cerris", height=17.0, crown_base=.40, radius=5.2, envelope="ovoid",
        trunk_radius=.36, taper=.6, lean=.03, wander=.06, flare=.45, flare_roots=6, flute=.0, burl=.04,
        n1=10, angle1=(58, 34), tropism1=.03, wander1=.18, reach1=.95, kink1=.2,
        n2=6, angle2=50, ratio2=.55, tropism2=.04, wander2=.24,
        n3=4, angle3=48, ratio3=.45, card=.6, cards_per_m=3.0, leader=.85),
    "ulmus_minor": dict(
        seed=7107, bark="elm", leaf="elm", height=16.0, crown_base=.38, radius=5.4, envelope="vase",
        trunk_radius=.32, taper=.6, lean=.04, wander=.07, flare=.45, flare_roots=6, flute=.0, burl=.06,
        n1=9, angle1=(40, 26), tropism1=.07, wander1=.16, reach1=1.0, kink1=.15,
        n2=6, angle2=52, ratio2=.6, tropism2=-.02, wander2=.24,
        n3=5, angle3=55, ratio3=.5, card=.55, cards_per_m=3.4, leader=.5),
    "fraxinus_angustifolia": dict(
        seed=7109, bark="ash", leaf="ash", height=16.0, crown_base=.42, radius=5.0, envelope="ovoid",
        trunk_radius=.30, taper=.6, lean=.04, wander=.05, flare=.35, flare_roots=5, flute=.0, burl=.0,
        n1=9, angle1=(50, 30), tropism1=.08, wander1=.14, reach1=1.0, kink1=.1,
        n2=5, angle2=48, ratio2=.6, tropism2=.06, wander2=.18,
        n3=3, angle3=45, ratio3=.45, card=.65, cards_per_m=2.6, leader=.8),
    "carpinus_betulus": dict(
        seed=7113, bark="hornbeam", leaf="hornbeam", height=12.5, crown_base=.28, radius=4.6, envelope="ovoid",
        trunk_radius=.25, taper=.62, lean=.06, wander=.08, flare=.35, flare_roots=6, flute=.16, burl=.0,
        n1=12, angle1=(55, 36), tropism1=.03, wander1=.2, reach1=.95, kink1=.2,
        n2=6, angle2=50, ratio2=.58, tropism2=.0, wander2=.25,
        n3=5, angle3=50, ratio3=.5, card=.55, cards_per_m=3.8, leader=.7),
    "populus_nigra": dict(
        seed=7127, bark="poplar", leaf="poplar", height=21.0, crown_base=.34, radius=6.4, envelope="column",
        trunk_radius=.48, taper=.6, lean=.08, wander=.09, flare=.6, flare_roots=7, flute=.0, burl=.28,
        n1=11, angle1=(44, 26), tropism1=.07, wander1=.24, reach1=1.0, kink1=.3,
        n2=6, angle2=46, ratio2=.55, tropism2=.04, wander2=.26,
        n3=4, angle3=45, ratio3=.45, card=.62, cards_per_m=2.9, leader=.7),
    "salix_alba": dict(
        seed=7131, bark="willow", leaf="willow", height=14.0, crown_base=.24, radius=5.6, envelope="fountain",
        trunk_radius=.40, taper=.6, lean=.14, wander=.12, flare=.4, flare_roots=6, flute=.0, burl=.12,
        n1=8, angle1=(38, 30), tropism1=.02, wander1=.26, reach1=1.0, kink1=.4, split=2,
        n2=7, angle2=40, ratio2=.62, tropism2=-.07, wander2=.22,
        n3=5, angle3=35, ratio3=.55, card=.55, cards_per_m=3.8, leader=0),
    "salix_alba_pollard": dict(
        seed=7133, bark="willow", leaf="willow", height=6.0, crown_base=.4, radius=2.6, envelope="ball",
        trunk_radius=.34, taper=.92, lean=.08, wander=.06, flare=.35, flare_roots=5, flute=.0, burl=.3,
        pollard=2.3, n1=26, angle1=(30, 12), tropism1=.1, wander1=.06, reach1=1.0, kink1=0,
        n2=3, angle2=35, ratio2=.45, tropism2=.06, wander2=.12,
        n3=0, angle3=40, ratio3=.4, card=.5, cards_per_m=4.4, leader=0),
    "alnus_glutinosa": dict(
        seed=7137, bark="alder", leaf="alder", height=15.0, crown_base=.34, radius=3.8, envelope="cone",
        trunk_radius=.27, taper=.55, lean=.03, wander=.04, flare=.3, flare_roots=6, flute=.0, burl=.0,
        n1=14, angle1=(70, 46), tropism1=.0, wander1=.16, reach1=1.0, kink1=.1,
        n2=5, angle2=55, ratio2=.55, tropism2=-.02, wander2=.2,
        n3=3, angle3=50, ratio3=.45, card=.55, cards_per_m=3.4, leader=1.0),
    "acer_campestre": dict(
        seed=7139, bark="maple", leaf="maple", height=9.5, crown_base=.26, radius=4.2, envelope="ovoid",
        trunk_radius=.22, taper=.6, lean=.07, wander=.1, flare=.35, flare_roots=5, flute=.06, burl=.05,
        n1=11, angle1=(55, 36), tropism1=.03, wander1=.24, reach1=.95, kink1=.3,
        n2=6, angle2=52, ratio2=.58, tropism2=.0, wander2=.26,
        n3=4, angle3=50, ratio3=.5, card=.5, cards_per_m=4.0, leader=.5),
    # Field maple pollarded at about 3 m as a living vine support (arbustum);
    # Pliny names the opulus/maple for vines north of the Po (NH 17.35).
    "acer_campestre_arbustum": dict(
        seed=7141, bark="maple", leaf="maple", height=5.2, crown_base=.6, radius=1.9, envelope="ball",
        trunk_radius=.19, taper=.85, lean=.03, wander=.05, flare=.3, flare_roots=5, flute=.05, burl=.25,
        pollard=3.1, n1=14, angle1=(42, 20), tropism1=.06, wander1=.1, reach1=1.0, kink1=0,
        n2=3, angle2=40, ratio2=.5, tropism2=.0, wander2=.15,
        n3=0, angle3=40, ratio3=.4, card=.45, cards_per_m=3.6, leader=0),
}

SHRUBS = {
    "corylus_avellana": dict(
        seed=7149, bark="hazel", leaf="hazel", height=5.0, crown_base=.12, radius=2.6, envelope="fountain",
        stems=9, stem_radius=.045, stem_angle=18, trunk_radius=.06, taper=.7, lean=0, wander=.05, flare=0, flare_roots=0,
        flute=0, burl=0, n1=5, angle1=(48, 30), tropism1=.02, wander1=.2, reach1=.55, kink1=.1,
        n2=4, angle2=45, ratio2=.5, tropism2=.0, wander2=.25, n3=0, angle3=40, ratio3=.4,
        card=.5, cards_per_m=4.8, leader=0),
    "crataegus_monogyna": dict(
        seed=7151, bark="thorn", leaf="hawthorn", height=4.2, crown_base=.2, radius=2.2, envelope="ball",
        stems=3, stem_radius=.07, stem_angle=12, trunk_radius=.08, taper=.7, lean=.04, wander=.12, flare=.2, flare_roots=4,
        flute=.05, burl=.05, n1=8, angle1=(62, 40), tropism1=.0, wander1=.35, reach1=.6, kink1=.4,
        n2=5, angle2=60, ratio2=.5, tropism2=-.02, wander2=.35, n3=0, angle3=50, ratio3=.4,
        card=.42, cards_per_m=6.0, leader=0),
    "prunus_spinosa": dict(
        seed=7157, bark="thorn", leaf="blackthorn", height=2.6, crown_base=.12, radius=1.7, envelope="ball",
        stems=13, stem_radius=.025, stem_angle=22, trunk_radius=.03, taper=.7, lean=0, wander=.12, flare=0, flare_roots=0,
        flute=0, burl=0, n1=4, angle1=(65, 45), tropism1=.0, wander1=.4, reach1=.5, kink1=.4,
        n2=3, angle2=65, ratio2=.45, tropism2=-.02, wander2=.4, n3=0, angle3=50, ratio3=.4,
        card=.38, cards_per_m=6.5, leader=0),
    "sambucus_nigra": dict(
        seed=7163, bark="elder", leaf="elder", height=4.4, crown_base=.18, radius=2.5, envelope="fountain",
        stems=6, stem_radius=.06, stem_angle=20, trunk_radius=.07, taper=.7, lean=.02, wander=.08, flare=0, flare_roots=0,
        flute=0, burl=.05, n1=5, angle1=(55, 40), tropism1=-.05, wander1=.18, reach1=.6, kink1=.15,
        n2=4, angle2=50, ratio2=.5, tropism2=-.04, wander2=.2, n3=0, angle3=45, ratio3=.4,
        card=.58, cards_per_m=3.8, leader=0),
}

# Grapevine (Vitis vinifera): on a pollarded field-maple support (arbustum,
# placed together with acer_campestre_arbustum) and on a stake with a cross
# pole (iugum). Pliny NH 17.35 / Varro RR 1.8 describe both systems.
VINES = {
    "vitis_arbustum": dict(seed=7167, bark="vine", leaf="vine", support="tree", height=4.6, radius=2.2,
                           card=.55, cards_per_m=3.0),
    "vitis_stake": dict(seed=7169, bark="vine", leaf="vine", support="stake", height=1.9, radius=1.0,
                        card=.5, cards_per_m=3.4),
}

# Herb and crop cards share one clump mesh; per-instance custom data picks a
# tile of herbs_albedo.png or crops_albedo.png (see textures.py order).
CARD_MESHES = ("clump_near", "clump_far")

# Atlas tile order (4 x 4, row-major from the top-left), shared by textures.py,
# the Godot vegetation library and the review renders.
HERB_TILES = ["meadow", "pasture", "dry", "sedge", "rush", "reed", "reed_plume", "loosestrife",
              "poppy", "cornflower", "daisy", "sage", "knapweed", "buttercup", "carrot", "iris"]
CROP_TILES = ["wheat", "wheat_green", "barley", "emmer", "millet", "foxtail", "bean", "kale",
              "leek", "lentil", "stubble", "flax", "", "", "", ""]
