# frozen_string_literal: true

class AddTaskToItemCurrencies < ActiveRecord::Migration[8.1]
  def change
    # Which quest gates this trader offer. Canonical carries the task id on
    # 101 buy routes; the boolean alone could not name it.
    add_reference :item_currencies, :task, foreign_key: true, index: true
  end
end
