"""Tests for parse_itembatches.py (wiki itembatches -> parsed_items.json).

Run with: ~/.pyvenv-tarkov/bin/python -m unittest lib/wiki_parser/test_parse_itembatches.py
"""

import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from parse_itembatches import clean_value, first_hex, parse_batch_file  # noqa: E402

WEAPON_NODE = "57c44b372459772d2b39b8ce"
AMMO_NODE = "59e655cb86f77411dc52a77b"
ARMOR_NODE = "5e4abb5086f77406975c9342"
STOCK_NODE = "5649b0fc4bdc2d17108b4588"

WEAPON_WIKITEXT = """{{Infobox weapon
|image              =Asval.png
|AS VAL icon.png     (Icon is hidden on purpose, placed here for accessibility)
|type               =[[Weapons#Assault rifles|Assault rifle]]
|slot               =Primary
|weight             =2.5 kg
|grid               =5x2
|price              =
|trader             =[[Ref]] LL4<br/>[[Prapor]] LL4
|fire modes         =Single<br/>Full Auto
|sightrange         =420
|ergonomics         =59.5
|velocity           =293 m/s
|range              =400 m
|MOA                =3.44
|Weaprecoil         =Vertical: 54<br/>Horizontal: 184
|rof                =900
|caliber            =[[9x39mm]]
|def ammo           ={{57a0dfb82459774d3078b56c}}
|ammo               ={{9x39mm}}
|def mag            ={{57838f9f2459774a150289a0}}
|node               =%s
|ID                 =weapon_tochmash_val_9x39
}}

The '''{{PAGENAME}}''' is a silenced assault rifle.

==Mods==
<div style="display:table"><tabber>Muzzle=
<div class="mobileonly">'''Muzzle'''</div>
{{57c44dd02459772d2e0ae249}}<br/>
{{57838c962459774a1651ec63}}<br/>
|-|Pistol grip=
<div class="mobileonly">'''Pistol grip'''</div>
{{5a69a2ed8dc32e000d46d1f1}}<br/>
|-|Magazine=
<div class="mobileonly">'''Magazine'''</div>
{{57838f9f2459774a150289a0}}
</tabber></div>

==Weapon variants==
{|class="wikitable"
!Image
!Weapon Variant
!Attachments
|-
![[File:AS VAL Kobra Icon.png|center]]
|AS VAL Kobra
|
{{57c44dd02459772d2e0ae249}}<br/>
{{57c44e7b2459772d28133248}}<br/>
{{57c44f4f2459772d2c627113}}<br/>
|}

{{Navbox weapons}}
[[Category:Weapons]]
[[fr:AS VAL]]
[[ru:АС ВАЛ]]
""" % WEAPON_NODE

AMMO_WIKITEXT = """{{Infobox ammo
|image              =EKOIMAGE.png
|type               =Round
|slot               =
|weight             =0.01 kg
|grid               =1x1
|price              =
|trader             =[[Jaeger]] LL1
|velocity           =770 m/s
|damage             =73
|accuracy           =<font color="red">-10</font>
|recoil             =<font color="green">-15</font>
|penetration        =30
|node               =%s
|id                 =patron_366_TKM_EKO
}}

'''{{PAGENAME}}''' is a cartridge.
""" % AMMO_NODE

ARMOR_WIKITEXT = """{{Infobox gear
|image              =Granit.png
|type               =[[Armor vests|Armor vest]]
|slot               =[[Armor vests|Body armor]]
|weight             =8.5 kg
|armor              =5
|default plates     =2x {{65573fa5655447403702a816}}
|default plates armor class =5
|max uses           =100
|effect             =Provides 9 inventory slots while only taking up 1
|node               =%s
|ID                 =armor_granit_sapi
}}

'''{{PAGENAME}}''' is body armor.
""" % ARMOR_NODE

STOCK_WIKITEXT = """{{Infobox weapon
|type               =[[Weapon mods#Gear Mods|Stock]]
|slot               =Stock
|weight             =0.3 kg
|node               =%s (Black)
                     5cbdb1b0ae9215000d50e105 (Plum)
|ID                 =stock_ak74_polymer
}}

'''{{PAGENAME}}''' is a stock.
""" % STOCK_NODE

INTERWIKI_WIKITEXT = """{{Infobox item
|type               =[[Category:Weapons]]
|slot               ={{Navbox weapons}}
|trader             =[[fr:Quelque chose]]
|node               =5c0faeddd174af02a962601f
}}

'''{{PAGENAME}}''' is a test page.
"""

STUB_WIKITEXT = """'''{{PAGENAME}}''' amplify low level sounds.

{| class="wikitable sortable"
!Type
!Name
|-
|Headset
|Peltor
|}
"""

NO_NODE_WIKITEXT = """{{Infobox item
|type               =Valuable
|weight             =0.1 kg
}}

'''{{PAGENAME}}''' has no node.
"""

BAD_NODE_WIKITEXT = """{{Infobox item
|type               =Valuable
|node               =N/A
}}

'''{{PAGENAME}}''' has a non-hex node.
"""


class ParseItembatchesTest(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp(prefix="wiki_parser_test_")
        self.batch_path = os.path.join(self.tmpdir, "wiki_batch_000.json")
        self.write_batch([
            ("AS VAL 9x39 special assault rifle", WEAPON_WIKITEXT),
            (".366 TKM EKO", AMMO_WIKITEXT),
            ("Granit SAPI", ARMOR_WIKITEXT),
            ("AK-74 polymer stock", STOCK_WIKITEXT),
            ("Interwiki test page", INTERWIKI_WIKITEXT),
            ("Earpieces", STUB_WIKITEXT),
            ("No node page", NO_NODE_WIKITEXT),
            ("Bad node page", BAD_NODE_WIKITEXT),
        ])

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def write_batch(self, pages):
        batch = {"query": {"pages": []}}
        for i, (title, content) in enumerate(pages):
            batch["query"]["pages"].append({
                "pageid": i,
                "ns": 0,
                "title": title,
                "revisions": [{
                    "slots": {"main": {"contentmodel": "wikitext", "content": content}}
                }],
            })
        with open(self.batch_path, "w") as f:
            json.dump(batch, f)

    def parse(self):
        return parse_batch_file(self.batch_path)

    # --- batch-level ---

    def test_parses_batch_into_dict_keyed_by_24_hex_node_id(self):
        result = self.parse()
        self.assertIn(WEAPON_NODE, result)
        self.assertIn(AMMO_NODE, result)
        self.assertIn(ARMOR_NODE, result)
        self.assertIn(STOCK_NODE, result)

    def test_full_name_is_page_title(self):
        result = self.parse()
        self.assertEqual("AS VAL 9x39 special assault rifle", result[WEAPON_NODE]["full_name"])
        self.assertEqual(".366 TKM EKO", result[AMMO_NODE]["full_name"])

    # --- infobox params with exact wiki spelling ---

    def test_weapon_infobox_params_extracted_with_wiki_spelling(self):
        infobox = self.parse()[WEAPON_NODE]["infobox"]
        self.assertEqual("Assault rifle", infobox["type"])
        self.assertEqual("Primary", infobox["slot"])
        self.assertEqual("[[Ref]] LL4<br/>[[Prapor]] LL4", infobox["trader"])
        self.assertEqual("Single<br/>Full Auto", infobox["fire_modes"])
        self.assertEqual("420", infobox["sightrange"])
        self.assertEqual("59.5", infobox["ergonomics"])
        self.assertEqual("3.44", infobox["MOA"])
        self.assertEqual("Vertical: 54<br/>Horizontal: 184", infobox["recoil"])
        self.assertEqual("900", infobox["rof"])
        self.assertEqual("9x39mm", infobox["caliber"])
        self.assertEqual("57a0dfb82459774d3078b56c", infobox["def_ammo"])
        self.assertEqual("9x39mm", infobox["ammo"])
        self.assertEqual("57838f9f2459774a150289a0", infobox["def_mag"])
        self.assertEqual(WEAPON_NODE, infobox["node"])
        self.assertEqual("weapon_tochmash_val_9x39", infobox["ID"])

    def test_malformed_unnamed_param_dropped(self):
        infobox = self.parse()[WEAPON_NODE]["infobox"]
        self.assertNotIn("1", infobox)

    def test_armor_infobox_params_extracted(self):
        infobox = self.parse()[ARMOR_NODE]["infobox"]
        self.assertEqual("5", infobox["armor"])
        self.assertEqual("2x {{65573fa5655447403702a816}}", infobox["default_plates"])
        self.assertEqual("5", infobox["default_plates_armor_class"])
        self.assertEqual("100", infobox["max_uses"])
        self.assertEqual("Provides 9 inventory slots while only taking up 1", infobox["effect"])

    # --- value cleaning ---

    def test_units_stripped_from_values(self):
        infobox = self.parse()[AMMO_NODE]["infobox"]
        self.assertEqual("0.01", infobox["weight"])
        self.assertEqual("770", infobox["velocity"])
        self.assertEqual("2.5", self.parse()[WEAPON_NODE]["infobox"]["weight"])
        self.assertEqual("400", self.parse()[WEAPON_NODE]["infobox"]["range"])
        self.assertEqual("293", self.parse()[WEAPON_NODE]["infobox"]["velocity"])

    def test_html_font_tags_removed_from_values(self):
        infobox = self.parse()[AMMO_NODE]["infobox"]
        self.assertEqual("-15", infobox["recoil"])
        self.assertEqual("-10", infobox["accuracy"])

    def test_plain_wikilink_and_template_values_unwrapped(self):
        self.assertEqual("20x1mm", clean_value("[[20x1mm]]"))
        self.assertEqual("Pistol", clean_value("[[Weapons#Pistols|Pistol]]"))
        self.assertEqual("6601546f86889319850bd566", clean_value("{{6601546f86889319850bd566}}"))

    def test_interwiki_category_and_navbox_filtered_out(self):
        self.assertEqual("", clean_value("[[fr:Test]]"))
        self.assertEqual("", clean_value("[[ru:Test]]"))
        self.assertEqual("", clean_value("[[Category:Weapons]]"))
        self.assertEqual("", clean_value("{{Navbox weapons}}"))

    def test_filtered_values_dropped_from_infobox(self):
        infobox = self.parse()["5c0faeddd174af02a962601f"]["infobox"]
        self.assertNotIn("type", infobox)
        self.assertNotIn("slot", infobox)
        self.assertNotIn("trader", infobox)

    # --- Mods tabber ---

    def test_mods_section_parsed_from_tabber(self):
        mods = self.parse()[WEAPON_NODE]["sections"]["mods"]
        self.assertEqual([
            {"slot": "Muzzle", "items": ["57c44dd02459772d2e0ae249", "57838c962459774a1651ec63"]},
            {"slot": "Pistol grip", "items": ["5a69a2ed8dc32e000d46d1f1"]},
            {"slot": "Magazine", "items": ["57838f9f2459774a150289a0"]},
        ], mods)

    def test_mods_last_entry_without_trailing_br(self):
        mods = self.parse()[WEAPON_NODE]["sections"]["mods"]
        self.assertEqual("57838f9f2459774a150289a0", mods[-1]["items"][0])

    # --- Weapon variants wikitable ---

    def test_weapon_variants_parsed_from_wikitable(self):
        variants = self.parse()[WEAPON_NODE]["sections"]["weapon_variants"]
        self.assertEqual([
            {
                "name": "AS VAL Kobra",
                "attachments": [
                    "57c44dd02459772d2e0ae249",
                    "57c44e7b2459772d28133248",
                    "57c44f4f2459772d2c627113",
                ],
            }
        ], variants)

    # --- node handling ---

    def test_multiline_node_with_color_annotations_takes_first_hex(self):
        result = self.parse()[STOCK_NODE]
        self.assertEqual(STOCK_NODE, result["infobox"]["node"])
        self.assertEqual("AK-74 polymer stock", result["full_name"])

    def test_first_hex_helper(self):
        self.assertEqual(
            STOCK_NODE,
            first_hex("%s (Black)\n                     5cbdb1b0ae9215000d50e105 (Plum)" % STOCK_NODE),
        )

    # --- skipped pages ---

    def test_pages_without_infobox_skipped(self):
        result = self.parse()
        self.assertNotIn("Earpieces", result)
        self.assertEqual(5, len(result))

    def test_pages_without_node_skipped(self):
        result = self.parse()
        self.assertNotIn("No node page", result)
        self.assertNotIn("Bad node page", result)


if __name__ == "__main__":
    unittest.main()