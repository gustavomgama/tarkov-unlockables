require "test_helper"

# == Schema Information
#
# Table name: tasks
#
#  id                   :bigint           not null, primary key
#  bsg_id               :string
#  full_name            :string
#  name                 :string
#  wiki_link            :string
#  given_by             :string
#  kappa_required       :boolean
#  lightkeeper_required :boolean
#  leads_tos_count      :integer          default(0)
#
class TaskTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
