# frozen_string_literal: true

module ItemComponent
  class CardComponent < ViewComponent::Base
    def initialize(card:)
      @card = card
    end

    def image_url
      card.images.first || "https://via.placeholder.com/150"
    end

    def category_badges
      card.categories.first(3)
    end
  end
end
