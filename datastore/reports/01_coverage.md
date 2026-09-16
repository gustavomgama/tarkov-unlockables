# Coverage & Integrity Report

Universe of distinct BSG ids across all item sources: **5489**

## Source sizes

| source | ids | share of universe |
| --- | ---: | ---: |
| tarkovdev/items | 5312 | 5312 (96%) |
| tarkovunlockables/items_index | 3399 | 3399 (61%) |
| officialwiki/parsed_items | 3899 | 3899 (71%) |
| tarkovmarket/items_all | 4403 | 4403 (80%) |
| tarkovdev questItems (separate dict) | 135 | 135 (2%) |
| tarkovdev specialItems | 37 | 37 (0%) |

## Pairwise overlap (intersection counts)

| A \ B | tarkovdev/items | tarkovunlockables/items_index | officialwiki/parsed_items | tarkovmarket/items_all |
| --- | ---: | ---: | ---: | ---: |
| tarkovdev/items | 5312 | 3399 | 3895 | 4360 |
| tarkovunlockables/items_index | 3399 | 3399 | 2682 | 3094 |
| officialwiki/parsed_items | 3895 | 2682 | 3899 | 3781 |
| tarkovmarket/items_all | 4360 | 3094 | 3781 | 4403 |

## Exclusives / gaps

- tarkovdev items NOT in any other source: **537**
- items_index ids missing from tarkovdev: **0**
- wiki ids missing from tarkovdev: **4**
- market ids missing from tarkovdev: **43**
- items_index ids not in wiki: **717**
- wiki ids not in items_index: **1217**

  - by tarkovdev `types`: [('noFlea', 426), ('preset', 183), ('barter', 10), ('ammoBox', 7), ('keys', 6), ('ammo', 4)]
  - by propertiesType: [('?', 341), ('ItemPropertiesPreset', 183), ('ItemPropertiesKey', 6), ('ItemPropertiesInfoContent', 5), ('ItemPropertiesAmmo', 2)]

## Display-name resolution (tarkovdev names are placeholders)

- full_name from officialwiki: **3899**
- else from tarkovmarket: **622**
- else from items_index: **301**
- **no display name anywhere: 667**

### Unresolved items (id / normalizedName / types)

- `567849dd4bdc2d150f8b456e` — `?` — types=None
- `57372a7f24597766fe0de0c1` — `545x39mm-bp-gs-ammo-pack-120-pcs-1` — types=['ammo', 'ammoBox', 'noFlea']
- `57372bad245977670b7cd242` — `545x39mm-bs-gs-ammo-pack-120-pcs-1` — types=['ammoBox', 'noFlea']
- `57372c56245977685e584582` — `545x39mm-bt-gs-ammo-pack-120-pcs-1` — types=['ammo', 'ammoBox', 'noFlea']
- `57372e1924597768553071c1` — `545x39mm-prs-gs-ammo-pack-120-pcs-1` — types=['ammoBox']
- `57372e94245977685648d3e1` — `545x39mm-ps-gs-ammo-pack-120-pcs-1` — types=['ammoBox']
- `57372f2824597769a270a191` — `545x39mm-t-gs-ammo-pack-120-pcs-1` — types=['ammoBox']
- `57372fc52459776998772ca1` — `545x39mm-us-gs-ammo-pack-120-pcs-1` — types=['ammoBox']
- `5841499024597759f825ff3e` — `makarov-pm-t-9x18pm-pistol-default` — types=['preset']
- `58414a3f2459775a77263531` — `vss-vintorez-9x39-special-sniper-rifle-default` — types=['noFlea', 'preset']
- `590c62a386f77412b0130255` — `?` — types=None
- `590dde5786f77405e71908b2` — `?` — types=None
- `5910922b86f7747d96753483` — `?` — types=None
- `591092ef86f7747bb8703422` — `?` — types=None
- `591093bb86f7747caa7bb2ee` — `?` — types=None
- `5937fd0086f7742bf33fc198` — `?` — types=None
- `5938188786f77474f723e87f` — `?` — types=None
- `5938878586f7741b797c562f` — `?` — types=None
- `593965cf86f774087a77e1b6` — `?` — types=None
- `5939a00786f7742fe8132936` — `?` — types=None
- `5939e5a786f77461f11c0098` — `?` — types=None
- `5939e9b286f77462a709572c` — `?` — types=None
- `593a87af86f774122f54a951` — `?` — types=None
- `59430b9b86f77403c27945fd` — `kalashnikov-ak-74n-545x39-assault-rifle-magpul` — types=['preset']
- `5a29276886f77435ed1b117c` — `?` — types=None
- `5a29284f86f77463ef3db363` — `?` — types=None
- `5a29357286f77409c705e025` — `?` — types=None
- `5a294d7c86f7740651337cf9` — `?` — types=None
- `5a294d8486f774068638cd93` — `?` — types=None
- `5a327f7286f7747668661419` — `serdyukov-sr-1mp-gyurza-9x21-pistol-tactical-1` — types=['preset']
- `5a327f9086f77475187e50a9` — `kalashnikov-akm-762x39-assault-rifle-2k17-ny` — types=['preset']
- `5a32808386f774764a3226d9` — `colt-m4a1-556x45-assault-rifle-2k17-ny` — types=['noFlea', 'preset']
- `5a43a85186f7746c914b947a` — `kalashnikov-aks-74un-545x39-assault-rifle-zenit` — types=['noFlea', 'preset']
- `5a43a86d86f7746c9d7395e8` — `sig-p226r-9x19-pistol-tactical` — types=['preset']
- `5a6860d886f77411cd3a9e47` — `?` — types=None
- `5a687e7886f7740c4a5133fb` — `?` — types=None
- `5a88aed086f77476cd391963` — `glock-17-9x19-pistol-fischer` — types=['preset']
- `5a88afdc86f7746de12fcc20` — `glock-17-9x19-pistol-alpha-wolf` — types=['preset']
- `5a8ae21486f774377b73cf5d` — `kalashnikov-akm-762x39-assault-rifle-t-ops` — types=['noFlea', 'preset']
- `5a8ae36686f774377d6ce226` — `colt-m4a1-556x45-assault-rifle-space-trooper` — types=['noFlea', 'preset']
- `5ac620eb86f7743a8e6e0da0` — `?` — types=None
- `5ae9a0dd86f7742e5f454a05` — `?` — types=None
- `5ae9a18586f7746e381e16a3` — `?` — types=None
- `5ae9a1b886f77404c8537c62` — `?` — types=None
- `5ae9a25386f7746dd946e6d9` — `?` — types=None
- `5ae9a3f586f7740aab00e4e6` — `?` — types=None
- `5ae9a4fc86f7746e381e1753` — `?` — types=None
- `5af04c0b86f774138708f78e` — `?` — types=None
- `5af04e0a86f7743a532b79e2` — `?` — types=None
- `5b43237186f7742f3a4ab252` — `?` — types=None
- `5b44abe986f774283e2e3512` — `tokarev-tt-33-762x25-tt-pistol-golden-default` — types=['preset']
- `5b4c81a086f77417d26be63f` — `?` — types=None
- `5ba3a078d4351e00334c96ca` — `kalashnikov-akm-762x39-assault-rifle-akmb` — types=['preset']
- `5ba3a14cd4351e003202017f` — `kalashnikov-akms-762x39-assault-rifle-akmsb-6p4m` — types=['preset']
- `5ba3a3dfd4351e0032020190` — `kalashnikov-akm-762x39-assault-rifle-akmp` — types=['preset']
- `5ba3a449d4351e0034778243` — `kalashnikov-akms-762x39-assault-rifle-akmsp` — types=['preset']
- `5ba3a4d1d4351e4502010622` — `kalashnikov-akmn-762x39-assault-rifle-akmn2-6p1n2` — types=['preset']
- `5ba3a53dd4351e3bac12056e` — `kalashnikov-akmsn-762x39-assault-rifle-akmsn2-6p4n2` — types=['preset']
- `5bbf1c5a88a45017bb03d7aa` — `colt-m4a1-556x45-assault-rifle-lvoa` — types=['preset']
- `5c0c1d2b86f77401c119d01f` — `kalashnikov-aks-74-545x39-assault-rifle-default` — types=['preset']
- … and 607 more

## Trade & task cross-reference integrity

- traders defined: 16
- barter.trader values not in traders: []
- task.trader values not in traders: []
- barter offeredItem ids not in tarkovdev items: 0
- barter requiredItems ids not in tarkovdev items: 0
- craft requiredItems ids not in tarkovdev items: 0
- craft productItem ids not in tarkovdev items: 0
- distinct craft.station ids: 8
    - `5d494a3f5b56502f18c98a0e` in tarkovdev items? False  name=None
    - `5d494a445b56502f18c98a10` in tarkovdev items? False  name=None
    - `5d484fd1654e76006732bf2e` in tarkovdev items? False  name=None
    - `5d484fda654e7600681d9315` in tarkovdev items? False  name=None
    - `5d484fba654e7600691aadf7` in tarkovdev items? False  name=None
    - `5d484fc8654e760065037abf` in tarkovdev items? False  name=None
    - `5d484fdf654e7600691aadf8` in tarkovdev items? False  name=None
    - `5d484fcd654e7668ec2ec322` in tarkovdev items? False  name=None
- distinct task.map ids: 13
    - `55f2d3fd4bdc2d5f408b4567` in tarkovdev items? False  normalizedName=None
    - `56f40101d2720b2a4d8b45d6` in tarkovdev items? False  normalizedName=None
    - `5704e3c2d2720bac5b8b4567` in tarkovdev items? False  normalizedName=None
    - `5704e4dad2720bb55b8b4567` in tarkovdev items? False  normalizedName=None
    - `5704e554d2720bac5b8b456e` in tarkovdev items? False  normalizedName=None
    - `5704e5fad2720bc05b8b4567` in tarkovdev items? False  normalizedName=None
    - `5714dbc024597771384a510d` in tarkovdev items? False  normalizedName=None
    - `5714dc692459777137212e12` in tarkovdev items? False  normalizedName=None
    - `59fc81d786f774390775787e` in tarkovdev items? False  normalizedName=None
    - `5b0fc42d86f7744a585f9105` in tarkovdev items? False  normalizedName=None
    - `653e6760052c01c1c805532f` in tarkovdev items? False  normalizedName=None
    - `6733700029c367a3d40b02af` in tarkovdev items? False  normalizedName=None
    - `69af492a4819ea4ba10a69c5` in tarkovdev items? False  normalizedName=None

## Objective type census (task objectives)

- giveItem: 305
- visit: 221
- shoot: 196
- findItem: 138
- plantItem: 129
- findQuestItem: 110
- giveQuestItem: 99
- extract: 86
- mark: 83
- buildWeapon: 30
- plantQuestItem: 13
- traderLevel: 10
- taskStatus: 9
- useItem: 9
- skill: 6
- sellItem: 5
- globalVariable: 4
- experience: 2
- traderStanding: 1
- dialogue: 1

## Reward block census

- startRewards keys: {'traderStanding': 517, 'items': 517, 'offerUnlock': 517, 'skillLevelReward': 517, 'traderUnlock': 517, 'craftUnlock': 517, 'achievement': 517, 'customization': 517, 'traderDialogueUnlock': 503, 'locationUnlock': 503}
- finishRewards keys: {'traderStanding': 517, 'items': 517, 'offerUnlock': 517, 'skillLevelReward': 517, 'traderUnlock': 517, 'craftUnlock': 517, 'achievement': 517, 'customization': 517, 'traderDialogueUnlock': 497, 'locationUnlock': 497}

## Reference-only datasets

- questItems: 135 (ids not all in items dict: 135)
- achievements: 123
- wiki barter_list rows: 443; wiki craft stations: 8
- tarkovmarket single-item example carries price fields: ['avg24hPrice', 'avg7daysPrice', 'bannedOnFlea', 'basePrice', 'haveMarketData', 'isFunctional', 'price', 'slots', 'traderName', 'traderPrice', 'traderPriceCur', 'traderPriceRub', 'updated']

## Cross-source agreement

- items the index calls **barterable**: 272; tarkovdev barters cover 268 (missing 4)
- items the index calls **craftable**: 184; tarkovdev crafts cover 184 (missing 0)
- items the index calls **currency-buyable**: 2965 (per-trader rows in tarkovdev, so exact overlap is not comparable)
- tarkovdev barters offer 445 items the index does not mark as barterable (newer offers than the index)
- tarkovdev crafts produce 19 items the index does not mark as craftable

- index `barter_unlocks` recipes: 52, distinct unlocked items: 45; 13 of them are offered by **no** tarkovdev barter (the API exposes no `barterUnlock` reward) -> merged from the index

- wiki barter_list rows (names only): 443 vs tarkovdev barters: 789 — the wiki lags the live API

- distinct craft station ids: 8; craft counts per id: [94, 41, 28, 26, 19, 4, 1, 1]

- tarkovmarket records: 4565; distinct bsgId: 4403; duplicate ids: 162 e.g. [('5d1b371186f774253763a656', 2), ('5aa7e373e5b5b000137b76f0', 2), ('5d02778e86f774203e7dedbe', 2)]

- `wiki_items_not_in_items_index.wiki` lists 152 ids absent from the derived index

