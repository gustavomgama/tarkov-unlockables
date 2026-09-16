# Task graph analysis

- tasks: **517**
- prerequisite edges: **255** (from `task_requirements` + `previous_tasks`)
- forward edges (`leads_to`): **29**
- cycles: **none**
- prerequisite ids outside the dataset: **0**
- forward edges whose prerequisite is not recorded on the target: **2**
    - `What’s on the Flash Drive?` → `Golden Swag` (target lists no prerequisite)
    - `Battery Change` → `Protect the Sky` (target lists no prerequisite)

## Prerequisite depth (longest chain to reach the task)

- max depth: **18**
- depth distribution: {0: 288, 1: 56, 2: 28, 3: 21, 4: 32, 5: 19, 6: 12, 7: 11, 8: 10, 9: 8, 10: 5, 11: 5, 12: 7, 13: 3, 14: 3, 15: 3, 16: 3, 17: 2, 18: 1}
- longest chain (19): Burning Rubber → Easy Money - Part 1 [PVP ZONE] → Easy Money - Part 2 [PVP ZONE] → Balancing - Part 1 [PVP ZONE] → Arena Business [PVP ZONE]
 → Professional Fitness - Part 1 [PVP ZONE] → Professional Fitness - Part 2 [PVP ZONE] → To Great Heights! - Part 1 [PVP ZONE] → To Great Heights! - Part 2 [PVP ZONE] → To Great Heights! - Part 3 [PVP ZONE] → To Great Heights! - Part 4 [PVP ZONE] → To Great Heights! - Part 5 [PVP ZONE] → To Great Heights! - Part 6 [PVP ZONE] → Hold the Lead [PVP ZONE] → Against the Conscience - Part 1 [PVP ZONE] → Against the Conscience - Part 2 [PVP ZONE] → Between Two Fires [PVP ZONE] → Surprise Gift [PVP ZONE] → Postponed Reward [PVP ZONE]

## Endgame requirements

### Kappa

- flagged tasks: **13**; with prerequisite closure: **13**
- total XP from the chain: **155,000**; highest character-level gate: **42**
- traders involved: {'jaeger': 4, 'skier': 3, 'ragman': 2, 'prapor': 1, 'therapist': 1, 'mechanic': 1, 'fence': 1}
- chain starts at: `Chemical - Part 1`, `Postman Pat - Part 1`, `Sew it Good - Part 1`, `Shooter Born in Heaven`, `The Tarkov Shooter - Part 1`

### Lightkeeper

- flagged tasks: **7**; with prerequisite closure: **7**
- total XP from the chain: **172,000**; highest character-level gate: **0**
- traders involved: {'mechanic': 7}
- chain starts at: `Network Provider - Part 1`

## Workload distribution

| trader | tasks | min level range | kappa chain |
| --- | ---: | --- | ---: |
| Mechanic | 91 | 0–45 | 1 |
| Prapor | 66 | 0–46 | 1 |
| Skier | 66 | 0–50 | 3 |
| Jaeger | 64 | 0–55 | 4 |
| Ragman | 58 | 0–42 | 2 |
| Therapist | 52 | 0–38 | 1 |
| Peacekeeper | 51 | 0–37 | 0 |
| Ref | 20 | 10–35 | 0 |
| BTR Driver | 19 | 0–0 | 0 |
| Fence | 16 | 0–50 | 1 |
| Lightkeeper | 14 | 0–35 | 0 |

- tasks with no map: **162**
- maps used: **13** of 17
- tasks per map: Streets of Tarkov 58, Customs 48, Lighthouse 43, Shoreline 42, Woods 42, Reserve 31, Factory 24, Interchange 19, Icebreaker 14, The Lab 13, Ground Zero 11, The Labyrinth 7, Night Factory 3

- character-level gates: {0: 282, 1: 4, 5: 5, 6: 3, 7: 3, 8: 6, 9: 21, 10: 22, 12: 26, 15: 4, 17: 16, 18: 6, 19: 7, 20: 1, 21: 7, 22: 3, 23: 1, 25: 3, 26: 11, 27: 6, 29: 1, 30: 2, 32: 1, 33: 7, 35: 7, 36: 8, 37: 8, 38: 4, 40: 17, 42: 13, 45: 3, 46: 1, 50: 7, 55: 1}
- factions: {'Any': 505, 'BEAR': 6, 'USEC': 6}

