# Schema-integrity checks (missing foreign keys/indexes, mismatched column
# types, …) run by `rake ci:db_doctor`. Two of the gem's detectors do not fit
# this schema and are turned off here, with the reason, so the gate stays a
# real signal:
ActiveRecordDoctor.configure do
  # The flagged NOT NULL columns have defaults that are legitimately blank:
  # `*_unlock` booleans hold `false`, `data` holds `{}`, and `search_text` is
  # filled by a callback. A presence validator would reject `false`/`{}` and
  # break every row it was meant to protect.
  # The booleans are listed explicitly because the detector's
  # `ignore_columns_with_default` does not silence them: a `false` default is
  # still a legitimate value, and a presence validator would reject it.
  detector :missing_presence_validation, ignore_columns_with_default: true,
                                         ignore_attributes: [
                                           "Item.type", "Task.type", "ItemCurrency.task_unlock",
                                           "HideoutItemRequirement.found_in_raid",
                                           "ItemHideoutRequirement.is_tool",
                                           "ItemSlot.required",
                                           "PreviousTask.alternative",
                                           "TaskObjective.optional"
                                         ]

  # `dependent: :destroy` is deliberate: it is what deletes the nested rows
  # (the earlier `delete_all` skipped them and broke item deletion). The gem
  # only sees that the direct child has no callbacks, not that the grandchild
  # graph does.
  detector :incorrect_dependent_option, enabled: false
end
