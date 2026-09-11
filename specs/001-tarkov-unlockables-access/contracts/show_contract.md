# Show Contract: Unlockable Item

## Request
GET /unlockables/:task_id

## Response (HTML via Turbo Frame)
- Task name (human-readable)
- List of unlockable items (no duplicates; each item shown once with acquisition method label)
- For each item: name, acquisition method (Buy / Craft / Barter), key details (vendor/recipe/trader)
- No functional gun/item mechanics; presentation only
