# frozen_string_literal: true

require "test_helper"

class Jev::RubricsTest < ActiveSupport::TestCase
  test "every dimension is a score question with four ordered levels" do
    questions = Jev::Rubrics.questions

    assert_equal Jev::Rubrics.keys, questions.map { |question| question[:id] }
    questions.each do |question|
      assert_equal "score", question[:type]
      assert_equal 4, question[:criteria].length
      assert_includes question[:instructions], "`path`"
    end
  end

  test "the gated dimensions are all real dimensions" do
    assert_empty Jev::Audit::SEVERE.keys - Jev::Rubrics.keys
  end

  test "code files get every dimension" do
    assert_equal Jev::Rubrics.keys, Jev::Rubrics.applicable("app/models/item.rb")
    assert_equal Jev::Rubrics.keys, Jev::Rubrics.applicable("app/views/items/show.html.erb")
  end

  test "infrastructure files skip the dimensions that do not apply" do
    expected = Jev::Rubrics.keys - %i[test_adequacy performance]

    assert_equal expected, Jev::Rubrics.applicable("Dockerfile")
    assert_equal expected, Jev::Rubrics.applicable(".github/workflows/ci.yml")
    assert_equal expected, Jev::Rubrics.applicable("bin/setup")
    # A .rb file under config/, db/ or bin/ is infrastructure whatever its
    # extension.
    assert_equal expected, Jev::Rubrics.applicable("config/ci.rb")
    assert_equal expected, Jev::Rubrics.applicable("config/environments/production.rb")
    assert_equal expected, Jev::Rubrics.applicable("db/seeds.rb")
    assert_equal expected, Jev::Rubrics.applicable("lib/tasks/ci.rake")
  end

  test "questions_for only asks the dimensions that apply" do
    ids = Jev::Rubrics.questions_for("Dockerfile").map { |question| question[:id] }

    refute_includes ids, :test_adequacy
    refute_includes ids, :performance
    assert_includes ids, :security
  end

  test "the scorecard covers the quality axes the project cares about" do
    assert_equal %i[security performance code_quality correctness_risk test_adequacy
                    over_engineering error_handling data_integrity],
                 Jev::Rubrics.keys
  end
end
