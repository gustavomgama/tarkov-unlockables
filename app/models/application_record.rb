class ApplicationRecord < ActiveRecord::Base
  include LooseSearchable

  primary_abstract_class
end
