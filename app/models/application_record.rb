class ApplicationRecord < ActiveRecord::Base
  include LooseSearchable

  primary_abstract_class

  # Normalizes URL attributes to http/https only. Anything else
  # (javascript:, data:, vbscript:, etc.) is dropped to nil so it can
  # never be rendered as an href.
  def self.normalizes_links(*attributes)
    attributes.each do |attr|
      normalizes attr, with: ->(value) {
        stripped = value.to_s.strip
        stripped.start_with?("http://", "https://") ? stripped : nil
      }
    end
  end
end
