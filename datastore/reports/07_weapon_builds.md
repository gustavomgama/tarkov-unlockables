# Weapon build analysis

- weapons (`ItemPropertiesWeapon`): **171**
- with at least one mod slot: **162**
- configurations too large to count exactly (capped at 1,000,000,000,000): **109**
- number of distinct valid configurations for the largest exact build: **603,197,456,000**

## Weapons with the most build options

| weapon | required slots | optional slots | configurations |
| --- | ---: | ---: | ---: |
| Colt M4A1 5.56x45 assault rifle | 4 | 2 | > 1,000,000,000,000 (capped) |
| MP-133 12ga pump-action shotgun | 4 | 2 | > 1,000,000,000,000 (capped) |
| SV-98 7.62x54R bolt-action sniper rifle | 1 | 5 | > 1,000,000,000,000 (capped) |
| Kalashnikov AK-74N 5.45x39 assault rifle | 2 | 8 | > 1,000,000,000,000 (capped) |
| MP-153 12ga semi-automatic shotgun | 4 | 2 | > 1,000,000,000,000 (capped) |
| TOZ Simonov SKS 7.62x39 carbine | 3 | 1 | > 1,000,000,000,000 (capped) |
| Saiga-12K ver.10 12ga semi-automatic shotgun | 2 | 8 | > 1,000,000,000,000 (capped) |
| VSS Vintorez 9x39 special sniper rifle | 3 | 5 | > 1,000,000,000,000 (capped) |
| AS VAL 9x39 special assault rifle | 3 | 6 | > 1,000,000,000,000 (capped) |
| Kalashnikov AKS-74U 5.45x39 assault rifle | 2 | 5 | > 1,000,000,000,000 (capped) |
| Kalashnikov AKS-74UN 5.45x39 assault rifle | 2 | 6 | > 1,000,000,000,000 (capped) |
| Kalashnikov AKS-74UB 5.45x39 assault rifle | 2 | 6 | > 1,000,000,000,000 (capped) |
| Molot Arms Simonov OP-SKS 7.62x39 carbine | 3 | 2 | > 1,000,000,000,000 (capped) |
| SIG MPX 9x19 submachine gun | 3 | 2 | > 1,000,000,000,000 (capped) |
| HK MP5 9x19 submachine gun (Navy 3 Round Burst) | 2 | 1 | > 1,000,000,000,000 (capped) |
| PP-19-01 Vityaz 9x19 submachine gun | 2 | 7 | > 1,000,000,000,000 (capped) |
| Kalashnikov AKM 7.62x39 assault rifle | 2 | 8 | > 1,000,000,000,000 (capped) |
| Molot Arms VPO-136 Vepr-KM 7.62x39 carbine | 2 | 8 | > 1,000,000,000,000 (capped) |
| Molot Arms VPO-209 .366 TKM carbine | 2 | 8 | > 1,000,000,000,000 (capped) |
| Saiga-9 9x19 carbine | 2 | 6 | > 1,000,000,000,000 (capped) |

## Exact build counts (most constrained weapons with slots)

| weapon | required slots | optional slots | configurations |
| --- | ---: | ---: | ---: |
| MP-43 12ga sawed-off double-barrel shotgun | 1 | 0 | 2 |
| 20x1mm toy gun | 1 | 0 | 2 |
| MP-43-1C 12ga double-barrel shotgun | 1 | 1 | 8 |
| PB 9x18PM silenced pistol | 1 | 2 | 12 |
| PP-91-01 Kedr-B 9x18PM submachine gun | 2 | 1 | 18 |
| PPSh-41 7.62x25 submachine gun | 3 | 1 | 24 |
| Stechkin APS 9x18PM machine pistol | 1 | 4 | 48 |
| Stechkin APB 9x18PM silenced machine pistol | 1 | 5 | 96 |
| TOZ KS-23M 23x75mm pump-action shotgun | 4 | 1 | 96 |
| Tokarev AVT-40 7.62x54R automatic rifle | 3 | 1 | 126 |
| Tokarev TT-33 7.62x25 TT pistol | 2 | 3 | 240 |
| Tokarev TT-33 7.62x25 TT pistol (Golden) | 2 | 3 | 240 |
| PP-91 Kedr 9x18PM submachine gun | 1 | 2 | 798 |
| PP-9 Klin 9x18PMM submachine gun | 1 | 2 | 798 |
| Yarygin MP-443 Grach 9x19 pistol | 1 | 2 | 1,636 |

- 9 entries typed as weapons have no mod slots at all (signal cartridges, launchers): one configuration each, listed in `weapon_build_stats`.

## Wiki build vs preset part list

- wiki builds matched to a preset: **101**
- wiki attachment list is a subset of the preset's contained items: **99**
- API-only parts per build: {1: 9, 2: 82, 3: 7, 4: 2, 5: 1} — the preset
  list additionally carries the base weapon itself and a loaded magazine,
  which the wiki's attachment table does not list.

## Required slots no item can fill

- none: every required slot has at least one item that exists in the dataset.

