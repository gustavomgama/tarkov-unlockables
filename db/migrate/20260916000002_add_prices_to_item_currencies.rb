# frozen_string_literal: true

class AddPricesToItemCurrencies < ActiveRecord::Migration[8.1]
  def change
    # Canonical prices every buy route: `price` in the offer's own currency,
    # `price_rub` converted, and `buy_limit` per reset. Only the 2,658
    # tarkovdev `buy` routes carry them; index-only offers stay null.
    add_column :item_currencies, :price, :bigint
    add_column :item_currencies, :price_rub, :bigint
    add_column :item_currencies, :buy_limit, :integer
  end
end
