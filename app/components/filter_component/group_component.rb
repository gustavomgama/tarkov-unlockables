# frozen_string_literal: true

module FilterComponent
  class GroupComponent < ViewComponent::Base
    def initialize(title:, name:, options:, selected: [])
      @title = title
      @name = name
      @options = options
      @selected = selected
    end

    def checked?(value)
      @selected.include?(value)
    end
  end
end
