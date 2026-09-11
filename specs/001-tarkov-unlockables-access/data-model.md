# Data Model: Tarkov Unlockables Access System

## Entities

### Task
- `id`: integer (PK, independent)
- `name`: string (human-readable, unique per task)
- `completion_status`: boolean (default false)
- `required_level`: integer (optional)
- `required_reputation`: string (optional)
- `created_at`, `updated_at`: timestamps

### UnlockableItem
- `id`: integer (PK, independent)
- `name`: string (human-readable, canonical)
- `item_type`: enum [buyable, craftable, barterable]
- `task_id`: integer (FK to Task, no cascade delete)
- `created_at`, `updated_at`: timestamps

### BuyableItem
- `id`: integer (PK, independent)
- `unlockable_item_id`: integer (FK, no cascade)
- `vendor_name`: string
- `price`: string (human-readable, e.g., "15,000 ₽")
- `loyalty_level`: integer

### CraftableItem
- `id`: integer (PK, independent)
- `unlockable_item_id`: integer (FK, no cascade)
- `crafting_station`: string
- `required_materials`: text (human-readable list)
- `skill_level`: integer

### BarterableItem
- `id`: integer (PK, independent)
- `unlockable_item_id`: integer (FK, no cascade)
- `trader_name`: string
- `required_goods`: text (human-readable)
- `loyalty_level`: integer

## Relationships
- Task → UnlockableItem (1:N, independent deletion)
- UnlockableItem → BuyableItem / CraftableItem / BarterableItem (1:1 per subtype, independent deletion)

## Constraints
- No cascading deletes; each record independent.
- `name` fields human-readable (no raw IDs shown to users).
- `item_type` determines which subtype table is queried.
