# Reconnaissance

```
==========================================================================================
TARKOVDEV /items  data keys: ['items', 'itemCategories', 'handbookCategories', 'fleaMarket', 'armorMaterials', 'playerLevels', 'mastering', 'skills', 'specialItems', 'settings']
==========================================================================================
  data[items]: dict len=5312
  data[itemCategories]: dict len=112
  data[handbookCategories]: dict len=88
  data[fleaMarket]: dict len=8
  data[armorMaterials]: dict len=8
  data[playerLevels]: list len=79
  data[mastering]: list len=82
  data[skills]: list len=49
  data[specialItems]: list len=37
  data[settings]: dict len=3

items: 5312  id sample=['5447a9cd4bdc2dbd208b4567', '5447ac644bdc2d6c208b4567']

### item  (5312 records)
    id                                   str                5312/5312
    name                                 str                5312/5312
    shortName                            str                5312/5312
    normalizedName                       str                5312/5312
    updated                              str                5312/5312
    width                                int                5312/5312
    height                               int                5312/5312
    weight                               float              5312/5312
    lastOfferCount                       int                5312/5312
    types                                list(2)            5312/5312
    wikiLink                             str                5312/5312
    link                                 str                5312/5312
    iconLink                             str                5312/5312
    gridImageLink                        str                5312/5312
    baseImageLink                        str                5312/5312
    inspectImageLink                     str                5312/5312
    image512pxLink                       str                5312/5312
    image8xLink                          str                5312/5312
    containsItems                        list(12)           5312/5312
    discardLimit                         int                5312/5312
    basePrice                            int                5312/5312
    categories                           list(4)            5312/5312
    handbookCategories                   list(2)            5312/5312
    lastLowPrice                         int                5312/5312
    avg24hPrice                          int                5312/5312
    changeLast48h                        int                5312/5312
    changeLast48hPercent                 float              5312/5312
    lastScan                             str                5312/5312
    properties                           dict(28)           5312/5312
    minLevelForFlea                      int                5312/5312
    backgroundColor                      str                5312/5312
    conflictingItems                     list(0)            5312/5312
    conflictingSlotIds                   list(0)            5312/5312
    conflictingCategories                list(0)            5312/5312
    buyFromTrader                        list(1)            5312/5312
    sellToTrader                         list(6)            5312/5312
    description                          str                4828/5312
    stackMaxSize                         int                4828/5312
    hasGrid                              bool               4828/5312
    high24hPrice                         int                4116/5312
    low24hPrice                          int                2732/5312
    ergonomicsModifier                   int                2466/5312
    velocity                             int                2466/5312
    accuracyModifier                     int                2295/5312
    recoilModifier                       int                2295/5312
    loudness                             int                2295/5312
    maxDurability                        int                626/5312
    armorClass                           int                521/5312
    blocksHeadphones                     bool               492/5312
    tracer                               bool               201/5312
    tracerColor                          str                201/5312
    ammoType                             str                201/5312
    projectileCount                      int                201/5312
    damage                               int                201/5312
    armorDamage                          int                201/5312
    fragmentationChance                  float              201/5312
    ricochetChance                       float              201/5312
    penetrationPower                     int                201/5312
    recoil                               int                201/5312

--- sample item ---
    id = "5447a9cd4bdc2dbd208b4567"
    name = "5447a9cd4bdc2dbd208b4567 Name"
    shortName = "5447a9cd4bdc2dbd208b4567 ShortName"
    normalizedName = "colt-m4a1-556x45-assault-rifle"
    description = "5447a9cd4bdc2dbd208b4567 Description"
    updated = "2026-09-03T04:18:06.000Z"
    width = 1
    height = 1
    weight = 0.75
    lastOfferCount = 30
    types = ["gun", "wearable"]
    wikiLink = "https://escapefromtarkov.fandom.com/wiki/Colt_M4A1_5.56x45_assault_rifle"
    link = "https://tarkov.dev/item/colt-m4a1-556x45-assault-rifle"
    iconLink = "https://assets.tarkov.dev/5447a9cd4bdc2dbd208b4567-icon.webp"
    gridImageLink = "https://assets.tarkov.dev/5447a9cd4bdc2dbd208b4567-grid-image.webp"
    baseImageLink = "https://assets.tarkov.dev/5447a9cd4bdc2dbd208b4567-base-image.webp"
    inspectImageLink = "https://assets.tarkov.dev/5447a9cd4bdc2dbd208b4567-image.webp"
    image512pxLink = "https://assets.tarkov.dev/5447a9cd4bdc2dbd208b4567-512.webp"
    image8xLink = "https://assets.tarkov.dev/5447a9cd4bdc2dbd208b4567-8x.webp"
    containsItems = [{"item": "55d4b9964bdc2d1d4e8b456e", "count": 1, "attributes": {}}, {"item": "55d4887d4bdc2d962f8b4570", "count": 1, "a…
    discardLimit = -1
    basePrice = 18397
    categories = ["5447b5f14bdc2d61278b4567", "5422acb9af1c889c16000029", "566162e44bdc2d3f298b4573", "54009119af1c881c07000029"]
    handbookCategories = ["5b5f78fc86f77409407a7f90", "5b5f78dc86f77409407a7f8e"]
    lastLowPrice = 17000
    avg24hPrice = 66091
    low24hPrice = 17000
    high24hPrice = 218628
    changeLast48h = -5708
    changeLast48hPercent = -7.95
    lastScan = "2026-09-03T03:28:02.000Z"
    properties = {"propertiesType": "ItemPropertiesWeapon", "caliber": "Caliber556x45NATO", "ergonomics": 48, "recoilVertical": 119, "rec…
    minLevelForFlea = 25
    maxDurability = 100
    ergonomicsModifier = 48
    stackMaxSize = 1
    velocity = 0
    hasGrid = false
    backgroundColor = "black"
    conflictingItems = []
    conflictingSlotIds = []
    conflictingCategories = []
    buyFromTrader = [{"trader": "5a7c2eca46aef81a7ca2145d", "price": 22997, "priceRUB": 22997, "currency": "RUB", "currencyItem": "5449016a4…
    sellToTrader = [{"trader": "54cb50c76803fa8b248b4571", "price": 7358, "priceRUB": 7358, "currency": "RUB", "currencyItem": "5449016a4bd…

--- itemCategories sample ---
    id = "5447b5f14bdc2d61278b4567"
    name = "5447b5f14bdc2d61278b4567 Name"
    normalizedName = "assault-rifle"
    parent = "5422acb9af1c889c16000029"
    children = []
--- handbookCategories sample ---
    id = "5b5f78fc86f77409407a7f90"
    name = "5b5f78fc86f77409407a7f90"
    normalizedName = "assault-rifles"
    imageLink = "https://assets.tarkov.dev/handbook-category-5b5f78fc86f77409407a7f90-icon.webp"
    minLevelForFlea = 25
    parent = "5b5f78dc86f77409407a7f8e"
    children = []

--- fleaMarket / armorMaterials / playerLevels / settings ---
  fleaMarket: dict len=8
      [name] = "FleaMarket"
  armorMaterials: dict len=8
      [Aluminium] = {"id": "Aluminium", "name": "MatAluminium", "destructibility": 0.45, "explosionDestructibility": 0.45, "maxRepairDegradation": 0.1, "maxRepairKitDegradation": 0.09, "minRepairDegradation": 0.06, "minR…
  playerLevels: list len=79
      [0] = {"level": 1, "exp": 0, "levelBadgeImageLink": "https://assets.tarkov.dev/player-level-group-1.png"}
  mastering: list len=82
      [0] = {"id": "M4", "weapons": ["5c07c60e0db834002330051f", "5447a9cd4bdc2dbd208b4567", "5bb2475ed4351e00853264e3", "5d43021ca4b9362eab4b5e25", "68a639748e1fe612970728e9", "68a6399922b1e0bd360afe56", "6895bb…
  skills: list len=49
      [0] = {"id": "AimDrills", "name": "AimDrills", "normalizedName": "aim-drills", "wikiLink": "https://escapefromtarkov.fandom.com/wiki/Aim_Drills", "imageLink": "https://assets.tarkov.dev/skill-AimDrills-icon…
  specialItems: list len=37
      [0] = "5f4fbaaca5573a5ac31db429"
  settings: dict len=3
      [scavCooldownSeconds] = 1500

==========================================================================================
TARKOVDEV /tasks  data keys: ['tasks', 'questItems', 'achievements', 'prestige']
==========================================================================================
  data[tasks]: dict len=517
  data[questItems]: dict len=135
  data[achievements]: dict len=123
  data[prestige]: list len=6

### task  (517 records)
    id                                   str                517/517
    name                                 str                517/517
    trader                               str                517/517
    wikiLink                             str                517/517
    minPlayerLevel                       int                517/517
    taskRequirements                     list(0)            517/517
    traderRequirements                   list(0)            517/517
    objectives                           list(2)            517/517
    failConditions                       list(0)            517/517
    startRewards                         dict(10)           517/517
    finishRewards                        dict(10)           517/517
    failureOutcome                       dict(10)           517/517
    restartable                          bool               517/517
    experience                           int                517/517
    factionName                          str                517/517
    normalizedName                       str                517/517
    kappaRequired                        bool               517/517
    lightkeeperRequired                  bool               517/517
    taskImageLink                        str                517/517
    map                                  str                517/517
    neededKeys                           list(0)            504/517
    availableDelaySecondsMin             int                503/517
    availableDelaySecondsMax             int                503/517
    otherRequirements                    list(1)            503/517
    gameMode                             list(1)            4/517
    requiredPrestige                     str                3/517

--- sample task ---
    id = "657315ddab5a49b71f098853"
    name = "657315ddab5a49b71f098853 name"
    trader = "54cb57776803fa99248b456e"
    wikiLink = "https://escapefromtarkov.fandom.com/wiki/First_in_Line"
    minPlayerLevel = 1
    taskRequirements = []
    traderRequirements = []
    objectives = [{"id": "65732ac3c67dcd96adffa3c7", "description": "65732ac3c67dcd96adffa3c7", "type": "visit", "optional": false, "zones": [{"id": "Sandbox_1_Medical…
    failConditions = []
    startRewards = {"traderStanding": [], "items": [], "offerUnlock": [], "skillLevelReward": [], "traderUnlock": [], "craftUnlock": [], "achievement": [], "customizatio…
    finishRewards = {"traderStanding": [{"standing": 0.1, "trader": "54cb57776803fa99248b456e"}], "items": [{"item": "5449016a4bdc2d6f028b456f", "count": 80000, "attribut…
    failureOutcome = {"traderStanding": [], "items": [], "offerUnlock": [], "skillLevelReward": [], "traderUnlock": [], "craftUnlock": [], "achievement": [], "customizatio…
    restartable = false
    experience = 3000
    factionName = "Any"
    neededKeys = []
    availableDelaySecondsMin = 0
    availableDelaySecondsMax = 0
    otherRequirements = [{"id": "68dfd6d220b777b168d7ef72", "type": "dialogue", "traders": ["54cb57776803fa99248b456e"]}]
    normalizedName = "first-in-line"
    kappaRequired = false
    lightkeeperRequired = false
    taskImageLink = "https://assets.tarkov.dev/657315ddab5a49b71f098853.webp"
    map = "653e6760052c01c1c805532f"

--- questItems sample ---
    id = "5937fd0086f7742bf33fc198"
    width = 1
    height = 1
    name = "5937fd0086f7742bf33fc198 Name"
    shortName = "5937fd0086f7742bf33fc198 ShortName"
    description = "5937fd0086f7742bf33fc198 Description"
    iconLink = "https://assets.tarkov.dev/5937fd0086f7742bf33fc198-icon.webp"
    gridImageLink = "https://assets.tarkov.dev/5937fd0086f7742bf33fc198-grid-image.webp"
    baseImageLink = "https://assets.tarkov.dev/5937fd0086f7742bf33fc198-base-image.webp"
    inspectImageLink = "https://assets.tarkov.dev/5937fd0086f7742bf33fc198-image.webp"
    image512pxLink = "https://assets.tarkov.dev/5937fd0086f7742bf33fc198-512.webp"
    image8xLink = "https://assets.tarkov.dev/5937fd0086f7742bf33fc198-8x.webp"
    normalizedName = "bronze-pocket-watch-on-a-chain"
--- achievements sample ---
    id = "6512ea46f7a078264a4376e4"
    name = "6512ea46f7a078264a4376e4 name"
    normalizedName = "pmcs-best-friend"
    description = "6512ea46f7a078264a4376e4 description"
    hidden = false
    side = "Pmc"
    normalizedSide = "pmc"
    rarity = "Achievements/Tab/CommonRarity"
    normalizedRarity = "common"
    playersCompletedPercent = 2.15
    adjustedPlayersCompletedPercent = 4.37
    imageLink = "https://assets.tarkov.dev/achievement-6512ea46f7a078264a4376e4-icon.webp"
--- prestige ---
    [{"id": "672df12f97f0469cea52f55e", "name": "672df12f97f0469cea52f55e name", "prestigeLevel": 1, "conditions": [{"id": "672df325cea63f5a813f7227", "description": "672df325cea63f5a813f7227", "type": "p…

### barter  (789 records)
    id                                   str                789/789
    trader                               str                789/789
    taskUnlock                           NoneType           789/789
    requiredItems                        list(1)            789/789
    restockAmount                        int                789/789
    buyLimit                             int                789/789
    minTraderLevel                       int                789/789
    offeredItem                          dict(3)            789/789

--- sample barter ---
    id = "6a70c1cc24dffc5ce90a53208"
    trader = "5a7c2eca46aef81a7ca2145d"
    taskUnlock = null
    requiredItems = [{"item": "5d1b309586f77425227d1676", "count": 2, "attributes": {}}]
    restockAmount = 2565000
    buyLimit = 10
    minTraderLevel = 2
    offeredItem = {"item": "5d1b304286f774253763a528", "count": 1, "attributes": {}}

### craft  (214 records)
    id                                   str                214/214
    requiredItems                        list(4)            214/214
    requiredQuestItems                   list(0)            214/214
    station                              str                214/214
    duration                             int                214/214
    gameEditions                         list(0)            214/214
    level                                int                214/214
    productItem                          dict(3)            214/214
    taskUnlock                           str                33/214

--- sample craft ---
    id = "6002ed409f2c60461a2d0f5a"
    requiredItems = [{"item": "5d4042a986f7743185265463", "count": 1, "attributes": {"tool": true}}, {"item": "590c2d8786f774245b1f03f3", "count": 1, "attributes": {"tool": true}}, {"item": "5af04b6486f774195a3ebb49", "count": 1, "attributes": {"tool": true}}, {"item": …
    requiredQuestItems = []
    station = "5d484fda654e7600681d9315"
    duration = 8200
    gameEditions = []
    level = 2
    productItem = {"item": "5d0376a486f7747d8050965c", "count": 1, "attributes": {}}

--- traders: 16 keyed by raw id ---

### trader  (16 records)
    id                                   str                16/16
    name                                 str                16/16
    description                          str                16/16
    normalizedName                       str                16/16
    currency                             str                16/16
    resetTime                            str                16/16
    discount                             int                16/16
    levels                               list(4)            16/16
    reputationLevels                     list(0)            16/16
    imageLink                            str                16/16
    buyAllowed                           dict(2)            16/16
    buyProhibited                        dict(2)            16/16

--- sample trader ---
    id = "54cb50c76803fa8b248b4571"
    name = "54cb50c76803fa8b248b4571 Nickname"
    description = "54cb50c76803fa8b248b4571 Description"
    normalizedName = "prapor"
    currency = "RUB"
    resetTime = "2026-08-31T05:27:49.000Z"
    discount = 0
    levels = [{"id": "54cb50c76803fa8b248b4571-1", "level": 1, "requiredPlayerLevel": 0, "requiredReputation": 0, "requiredCommerce": 0, "payRate": 0.4, "insurance…
    reputationLevels = []
    imageLink = "https://assets.tarkov.dev/54cb50c76803fa8b248b4571.webp"
    buyAllowed = {"category": ["5422acb9af1c889c16000029", "5485a8684bdc2da71d8b4567", "543be6564bdc2df4348b4568", "543be5664bdc2dd4348b4569", "57864bb7245977548b3b66c…
    buyProhibited = {"category": [], "items": ["62e910aaf957f2915e0a5e36", "64d0b40fbe2eed70e254e2d4", "65ddcc9cfa85b9f17d0dfb07", "65ddcc7aef36f6413d0829b9", "65ca457b4a…
  traders name/normalizedName:
    54cb50c76803fa8b248b4571  name="54cb50c76803fa8b248b4571 Nickname"  normalized="prapor"
    54cb57776803fa99248b456e  name="54cb57776803fa99248b456e Nickname"  normalized="therapist"
    579dc571d53a0658a154fbec  name="579dc571d53a0658a154fbec Nickname"  normalized="fence"
    58330581ace78e27b8b10cee  name="58330581ace78e27b8b10cee Nickname"  normalized="skier"
    5935c25fb3acc3127c3d8cd9  name="5935c25fb3acc3127c3d8cd9 Nickname"  normalized="peacekeeper"
    5a7c2eca46aef81a7ca2145d  name="5a7c2eca46aef81a7ca2145d Nickname"  normalized="mechanic"
    5ac3b934156ae10c4430e83c  name="5ac3b934156ae10c4430e83c Nickname"  normalized="ragman"
    5c0647fdd443bc2504c2d371  name="5c0647fdd443bc2504c2d371 Nickname"  normalized="jaeger"
    638f541a29ffd1183d187f57  name="638f541a29ffd1183d187f57 Nickname"  normalized="lightkeeper"
    68fe15910f29ba3fdbba9d54  name="68fe15910f29ba3fdbba9d54 Nickname"  normalized="taran"
    68fe15990f29ba3fdbba9d55  name="68fe15990f29ba3fdbba9d55 Nickname"  normalized="radio-station"
    656f0f98d80a697f855d34b1  name="656f0f98d80a697f855d34b1 Nickname"  normalized="btr-driver"
    6617beeaa9cfa777ca915b7c  name="6617beeaa9cfa777ca915b7c Nickname"  normalized="ref"
    688246518448b05efd61d461  name="688246518448b05efd61d461 Nickname"  normalized="mr-kerman"
    688246958448b05efd61d462  name="688246958448b05efd61d462 Nickname"  normalized="voevoda"
    69e0d6cc77b63940375b9173  name="69e0d6cc77b63940375b9173 Nickname"  normalized="survivor"

==========================================================================================
TARKOVDEV cross-refs
==========================================================================================
  barter.trader: 8 distinct, top [('6617beeaa9cfa777ca915b7c', 332), ('5a7c2eca46aef81a7ca2145d', 108), ('54cb50c76803fa8b248b4571', 69), ('5ac3b934156ae10c4430e83c', 67), ('5c0647fdd443bc2504c2d371', 61), ('5935c25fb3acc3127c3d8cd9', 60), ('54cb57776803fa99248b456e', 58), ('58330581ace78e27b8b10cee', 34)]
  craft.station: 8 distinct, top [('5d484fda654e7600681d9315', 94), ('5d484fba654e7600691aadf7', 41), ('5d484fcd654e7668ec2ec322', 28), ('5d484fdf654e7600691aadf8', 26), ('5d484fd1654e76006732bf2e', 19), ('5d484fc8654e760065037abf', 4), ('5d494a3f5b56502f18c98a0e', 1), ('5d494a445b56502f18c98a10', 1)]
  task.trader: 11 distinct, top [('5a7c2eca46aef81a7ca2145d', 91), ('54cb50c76803fa8b248b4571', 66), ('58330581ace78e27b8b10cee', 66), ('5c0647fdd443bc2504c2d371', 64), ('5ac3b934156ae10c4430e83c', 58), ('54cb57776803fa99248b456e', 52), ('5935c25fb3acc3127c3d8cd9', 51), ('6617beeaa9cfa777ca915b7c', 20)]
  item.types census: [('mods', 2295), ('noFlea', 1386), ('wearable', 747), ('preset', 484), ('barter', 339), ('keys', 256), ('ammoBox', 225), ('ammo', 212), ('gun', 171), ('pistolGrip', 139), ('rig', 91), ('provisions', 89), ('suppressor', 85), ('armor', 70), ('poster', 57), ('glasses', 51), ('backpack', 47), ('specialSlot', 44), ('meds', 43), ('helmet', 40), ('armorPlate', 38), ('container', 31), ('headphones', 25), ('injectors', 22), ('markedOnly', 18), ('grenade', 14)]
  item.categories sample: ["5447b5f14bdc2d61278b4567", "5422acb9af1c889c16000029", "566162e44bdc2d3f298b4573", "54009119af1c881c07000029"]

### tarkovmarket item  (4565 records)
    uid                                  str                4565/4565
    name                                 str                4565/4565
    tags                                 list(1)            4565/4565
    shortName                            str                4565/4565
    icon                                 str                4565/4565
    link                                 str                4565/4565
    wikiLink                             str                4565/4565
    img                                  str                4565/4565
    imgBig                               str                4565/4565
    bsgId                                str                4565/4565

--- sample ---
    uid = "f0fa8457-6638-4ad2-b7e8-4708033d8f39"
    name = "Secure Flash drive"
    tags = ["Barter"]
    bsgId = "590c621186f774138d11ea29"

  tags census top 30: [('Weapon_parts', 1845), ('Gear', 655), ('Weapon', 364), ('Barter', 320), ('Stocks_chassis', 290), ('Handguards', 278), ('Mounts', 278), ('Keys', 248), ('Magazines', 231), ('Ammo_boxes', 218), ('Ammo', 199), ('Barrels', 196), ('Not_Functional', 160), ('Flashhiders_brakes', 155), ('Pistol_grips', 135), ('Iron_sights', 130), ('Facecovers', 129), ('Receivers_slides', 110), ('Sights', 109), ('Assault_rifles', 93), ('Tactical_rigs', 91), ('Suppressors', 88), ('Helmets', 81), ('Muzzle_adapters', 65), ('Foregrips', 60), ('Pistols', 58), ('Cosmetics', 57), ('Headwear', 53), ('Armor_vests', 51), ('Auxiliary_parts', 49)]

### items_index.json  (400 records)
    slug                                 str                400/400
    full_name                            str                400/400
    short_name                           str                400/400
    links                                list(3)            400/400
    images                               list(9)            400/400
    properties                           dict(1)            400/400
    obtain_from                          list(1)            400/400
    categories                           list(2)            400/400
    bsg_id                               str                400/400
    sample: {"slug": "factory-emergency-exit-key", "full_name": "Factory emergency exit key", "short_name": "Factory", "links": ["https://tarkov.dev/item/factory-emergency-exit-key", "https://tarkov-market.com/item/factory_exit_key", "https://escapefromtarkov.fandom.com/wiki/Factory_emergency_exit_key"], "image…

### tasks_index.json  (400 records)
    bsg_id                               str                400/400
    full_name                            str                400/400
    name                                 str                400/400
    wiki_link                            str                400/400
    given_by                             str                400/400
    kappa_required                       str                400/400
    lightkeeper_required                 str                400/400
    leads_to                             list(0)            400/400
    requirements                         list(1)            400/400
    start_rewards                        list(1)            400/400
    finish_rewards                       list(1)            400/400
    sample: {"bsg_id": "5ae4493d86f7744b8e15aa8f", "full_name": "A Big Loss", "name": "a-big-loss", "wiki_link": "https://escapefromtarkov.fandom.com/wiki/A_Big_Loss", "given_by": "ragman", "kappa_required": "true", "lightkeeper_required": "false", "leads_to": [], "requirements": [{"player_level": "0", "trader_…

### traders_index.json  DICT 1 keys=['traders']

### traders_index.json (values)  (1 records)
    prapor                               dict(4)            1/1
    therapist                            dict(4)            1/1
    fence                                dict(4)            1/1
    skier                                dict(4)            1/1
    peacekeeper                          dict(4)            1/1
    mechanic                             dict(4)            1/1
    ragman                               dict(4)            1/1
    jaeger                               dict(4)            1/1
    lightkeeper                          dict(4)            1/1
    ref                                  dict(4)            1/1

### buyables_index.json  (400 records)
    item_id                              str                400/400
    item_name                            str                400/400
    trader_name                          str                400/400
    trader_level                         str                400/400
    currency                             str                400/400
    sample: {"item_id": "5448be9a4bdc2dfd2f8b456a", "item_name": "RGD-5 hand grenade", "trader_name": "prapor", "trader_level": "LL3", "currency": "RUB"}

### barteables_index.json  (400 records)
    requirements                         list(1)            400/400
    result                               list(1)            400/400
    sample: {"requirements": [{"items": [{"id": "573475fb24597737fb1379e1", "name": "Apollo Soyuz cigarettes", "count": "2"}], "task_id": "", "task_name": "", "trader_name": "prapor", "trader_level": "LL1"}], "result": [{"items": [{"id": "67506ca81f18589016006aa6", "name": "PNV-57E night vision goggles"}]}]}

### craftables_index.json  DICT 8 keys=['Bitcoin farm', 'Booze generator', 'Intelligence center', 'Lavatory', 'Medstation', 'Nutrition unit']
    values are lists, first(len=1): [{"input_items": [{"name": "Graphics card", "quantity": "1"}], "output_items": [{"name": "Physical Bitcoin", "quantity": "1"}], "task_requirements": "", "station": "Bitcoin farm", "station_level": ""}]

### task_gated_buyables.json  (119 records)
    bsg_id                               str                119/119
    full_name                            str                119/119
    name                                 str                119/119
    start_rewards                        list(0)            119/119
    finish_rewards                       list(1)            119/119
    sample: {"bsg_id": "", "full_name": "Advertising Business - Part 1", "name": "", "start_rewards": [], "finish_rewards": [{"item_id": "5648a69d4bdc2ded0b8b457b", "item_name": "BlackRock chest rig (Gray)", "trader_name": "ref", "trader_level": ""}]}

### task_gated_barters.json  (45 records)
    bsg_id                               str                45/45
    finish_rewards                       list(1)            45/45
    sample: {"bsg_id": "5ac3475486f7741d6224abd3", "finish_rewards": [{"barter_unlocks": [{"requirements": [{"items": [{"id": "573475fb24597737fb1379e1", "name": "Apollo Soyuz cigarettes", "count": "5"}], "trader_name": "therapist", "trader_level": "LL1"}], "result": [{"items": [{"id": "62a0a043cf4a99369e2624a5…

### task_gated_crafts.json  (34 records)
    bsg_id                               str                34/34
    start_rewards                        list(0)            34/34
    finish_rewards                       list(0)            34/34
    story_rewards                        list(1)            34/34
    sample: {"bsg_id": "", "start_rewards": [], "finish_rewards": [], "story_rewards": [{"craft_unlocks": [{"requirements": [{"items": [{"name": "UHF RFID Reader", "quantity": "1", "id": "5c052fb986f7746b2101e909"}, {"name": "Decrypted Sliderkey flash drive marked with A.P.", "quantity": "1", "id": "4053aef3-fa…

### officialwiki/parsed_items.json  DICT keyed by id, 3899 entries

### wiki parsed item  (2000 records)
    full_name                            str                2000/2000
    infobox                              dict(19)           2000/2000
    sections                             dict(2)            2000/2000
--- sample key=59e655cb86f77411dc52a77b ---
    full_name = ".366 TKM EKO"
    infobox = {"image": "EKOIMAGE.png", "icon": "EKOICON.png", "type": "Round", "weight": "0.01", "grid": "1x1", "trader": "[[Jaeger]] LL1", "velocity": "770", "dam…
    sections = {"mods": [], "weapon_variants": []}

### wiki barter_list  (443 records)
    trader_name                          str                443/443
    trader_level                         str                443/443
    task_requirement                     NoneType           443/443
    trade_items                          list(1)            443/443
    result_items                         list(1)            443/443
    section                              str                443/443
--- sample ---
    trader_name = "Prapor"
    trader_level = "Prapor LL1"
    task_requirement = null
    trade_items = [{"quantity": 2, "name": "Apollo Soyuz cigarettes"}]
    result_items = [{"quantity": 1, "name": "PNV-57E night vision goggles"}]
    section = "Prapor"

### officialwiki/craft_list.json stations=['Bitcoin farm', 'Booze generator', 'Intelligence center', 'Lavatory', 'Medstation', 'Nutrition unit', 'Water collector', 'Workbench']

### craft_list[Bitcoin farm]  (1 records)
    input_items                          list(1)            1/1
    output_items                         list(1)            1/1
    quest_requirement                    NoneType           1/1
    station                              str                1/1
    station_level                        NoneType           1/1
--- sample ---
    input_items = [{"name": "Graphics card", "quantity": 1}]
    output_items = [{"name": "Physical Bitcoin", "quantity": 1}]
    quest_requirement = null
    station = "Bitcoin farm"
    station_level = null
```
