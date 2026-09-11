# Quickstart: Tarkov Unlockables Access System

## Prerequisites
- Ruby 4.0.6, Rails 8.1.3, PostgreSQL running
- `bundle install`
- `rails db:migrate`

## Validation
1. `rails s`
2. Visit `/unlockables/1` (task 1)
3. Confirm: task name shown, items listed without duplicates, acquisition method clearly labeled, data human-readable.
4. Confirm DB independence: delete one item record; others remain intact.
