# Wiki cross-check

The wiki's trade and craft tables are name-only and lag the live API, so
they are used as corroboration, not as a source.

## Trades

- wiki rows: **443**
- matched to a canonical route (barter, tdev purchase or index claim): **379** (85%)
- wiki-only pairs: **62** (trades the wiki lists that no canonical route 
  covers — usually renamed or removed content)
- canonical (trader, item) pairs: **3512** — the wiki table covers a
  small, older slice of them, which is the expected direction of drift
- wiki item names absent from the dataset entirely: **16**

### Wiki-only trades (first 40)

- Jaeger → Kiba Arms International SPRM mount
- Jaeger → Magnum Research Desert Eagle L5 .357 pistol
- Jaeger → Magnum Research Desert Eagle L5 .50 AE pistol
- Mechanic → 20x1mm toy gun
- Mechanic → AS VAL MOD.4 9x39 special assault rifle
- Mechanic → Degtyarev RPDN 7.62x39 machine gun
- Mechanic → FN SCAR-H 7.62x51 assault rifle
- Mechanic → HK MP7A1 4.6x30 submachine gun
- Mechanic → HK UMP .45 ACP submachine gun
- Mechanic → Kalashnikov AK-104 7.62x39 assault rifle
- Mechanic → Kalashnikov PKM 7.62x54R machine gun
- Mechanic → Molot Arms Simonov OP-SKS 7.62x39 carbine
- Mechanic → Mosin 7.62x54R bolt-action rifle (Sniper)
- Mechanic → MP-133 12ga pump-action shotgun
- Mechanic → PP-19-01 Vityaz 9x19 submachine gun
- Mechanic → ProMag AK-A-16 73-round 7.62x39 magazine for AKM
- Mechanic → Remington Model 700 7.62x51 bolt-action sniper rifle
- Mechanic → Remington Model 870 12ga pump-action shotgun
- Mechanic → RPK-16 5.45x39 light machine gun
- Mechanic → Saiga-12K ver.10 12ga semi-automatic shotgun
- Mechanic → Steyr AUG A1 5.56x45 assault rifle
- Mechanic → Tokarev TT-33 7.62x25 TT pistol
- Peacekeeper → AR-15 Daniel Defense RIS II 9.5 handguard
- Peacekeeper → CQC Osprey MK4A plate carrier (Protection, MTP)
- Peacekeeper → FN40GL Mk2 40mm grenade launcher
- Peacekeeper → FN SCAR-H 7.62x51 assault rifle
- Peacekeeper → HK G28 7.62x51 marksman rifle
- Peacekeeper → HK MP7A2 4.6x30 submachine gun
- Peacekeeper → HK UMP .45 ACP submachine gun
- Peacekeeper → NFM THOR Integrated Carrier body armor (Without plates)
- Peacekeeper → Ops-Core FAST MT Super High Cut helmet (Black)
- Prapor → 6B23-1 body armor (EMR)
- Prapor → 6B43 Zabralo-Sh body armor (EMR) (Without plates)
- Prapor → 6L18 45-round 5.45x39 magazine for AK-74
- Prapor → 95-round 5.45x39 magazine for RPK-16
- Prapor → RSh-12 12.7x55 revolver
- Prapor → Serdyukov SR-1MP Gyurza 9x21 pistol
- Prapor → TKPD 9.3x64 carbine
- Prapor → Tokarev AVT-40 7.62x54R automatic rifle
- Prapor → TOZ KS-23M 23x75mm pump-action shotgun

## Ammo ballistics

- ammo types with both a wiki infobox and API properties: **198**
- field values compared: **1522**; equal after unit conversion and the
  wiki's 1-decimal rounding: **1510** (99%)

| field | compared | equal |
| --- | ---: | ---: |
| damage | 198 | 197 |
| penetration | 198 | 197 |
| armor_damage | 198 | 198 |
| velocity | 198 | 198 |
| ricochet | 188 | 186 |
| accuracy | 114 | 113 |
| recoil | 117 | 115 |
| durability_burn | 135 | 134 |
| heat | 176 | 172 |

### Substantive disagreements

| item | field | wiki | api |
| --- | --- | ---: | ---: |
| 20/70 Poleva-3 slug | damage | 140 | 120 |
| 40mm VOG-25 grenade | penetration | 1 | 0 |
| 7.62x51mm M61 | ricochet | 30% | 0.25 |
| 7.62x51mm M80A1 | ricochet | 25% | 0.3 |
| 9x21mm PS gzh | accuracy | +1 | 0 |
| 7.62x54mm R PS gzh | recoil | +10 | 0.08 |
| 9x21mm PS gzh | recoil | -3 | 0 |
| 7.62x25mm TT M856A1 | durability_burn | +6 | 1.8 |
| 20/70 TSS Armor Piercing Slug | heat | +144 | 2.4371 |
| 20/70 Dangerous Game Slug | heat | +134 | 2.3416 |
| 20/70 flechette | heat | +113 | 2.1349 |
| 7.62x25mm TT M856A1 | heat | +80 | 1.06 |

## Crafts

- wiki outputs: **213**
- matched by (station, product): **199** (93%)
- wiki-only crafts: **14**

### Wiki-only crafts

- Intelligence center → Decrypted Sliderkey flash drive marked with A.P.
- Intelligence center → Military flash drive with topographic intel
- Intelligence center → SSD with TerraGroup evidence
- Workbench → Equipment crate (BattlePass 0)
- Workbench → Equipment crate (Rare)
- Workbench → Kalashnikov AK-74M 5.45x39 assault rifle
- Workbench → Kalashnikov AK-74N 5.45x39 assault rifle
- Workbench → Kalashnikov AKM 7.62x39 assault rifle
- Workbench → Moreman's audio tape 1
- Workbench → Moreman's audio tape 2
- Workbench → PP-9 Klin 9x18PMM submachine gun
- Workbench → Supply crate (Rare)
- Workbench → Valuables crate (Rare)
- Workbench → Weapon crate (Rare)

### Wiki names with no dataset item

- `6B43 Zabralo-Sh body armor (EMR) (Without plates)`
- `6L18 45-round 5.45x39 magazine for AK-74`
- `95-round 5.45x39 magazine for RPK-16`
- `AR-15 Daniel Defense RIS II 9.5 handguard`
- `BNTI Gzhel-K body armor (Without plates)`
- `Equipment crate (BattlePass 0)`
- `Equipment crate (Rare)`
- `FORT Redut-M body armor (Without plates)`
- `FORT Redut-T5 body armor (Smog) (Without plates)`
- `IOTV Gen4 body armor (Full Protection Kit, MultiCam) (Without plates)`
- `Kiba Arms International SPRM mount`
- `NFM THOR Integrated Carrier body armor (Without plates)`
- `ProMag AK-A-16 73-round 7.62x39 magazine for AKM`
- `Supply crate (Rare)`
- `Valuables crate (Rare)`
- `Weapon crate (Rare)`

