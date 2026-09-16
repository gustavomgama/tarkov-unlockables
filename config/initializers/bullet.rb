# frozen_string_literal: true

# Bullet only marks an eager load "used" when ActiveRecord calls load_target.
# A preloaded *empty* collection is read straight off the target, so leaf tasks
# and unused rows get reported as unused eager loads and Bullet.raise 500s the
# page. Known false positives only; N+1 detection stays strict.
if defined?(Bullet) && Bullet.respond_to?(:add_safelist)
  Bullet.add_safelist type: :unused_eager_loading, class_name: "Task", association: :leads_tos
  Bullet.add_safelist type: :unused_eager_loading, class_name: "Task", association: :requirements
  Bullet.add_safelist type: :unused_eager_loading, class_name: "Requirement", association: :previous_tasks
  # A quest whose rewards carry no loose items, unlocks or craft outputs leaves
  # the nested :item preload with nothing to load. 53 of 468 quest pages hit
  # this and 500'd in development.
  Bullet.add_safelist type: :unused_eager_loading, class_name: "Reward", association: :loose_items
  Bullet.add_safelist type: :unused_eager_loading, class_name: "Reward", association: :offer_unlocks
  Bullet.add_safelist type: :unused_eager_loading, class_name: "Reward", association: :barter_unlocks
  Bullet.add_safelist type: :unused_eager_loading, class_name: "Reward", association: :craft_unlocks
end
