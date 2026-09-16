# frozen_string_literal: true

# Bullet only marks an eager load "used" when ActiveRecord calls load_target.
# A preloaded *empty* collection is read straight off the target, so leaf tasks
# and unused rows get reported as unused eager loads and Bullet.raise 500s the
# page. Known false positives only; N+1 detection stays strict.
if defined?(Bullet) && Bullet.respond_to?(:add_safelist)
  Bullet.add_safelist type: :unused_eager_loading, class_name: "Task", association: :leads_tos
  Bullet.add_safelist type: :unused_eager_loading, class_name: "Task", association: :requirements
  Bullet.add_safelist type: :unused_eager_loading, class_name: "Requirement", association: :previous_tasks
end
