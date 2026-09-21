# frozen_string_literal: true

require "test_helper"

class JevTest < ActiveSupport::TestCase
  setup do
    @key = ENV["TYPESAFE_API_KEY"]
    ENV.delete("TYPESAFE_API_KEY")
  end

  teardown do
    ENV.delete("TYPESAFE_API_KEY")
    ENV["TYPESAFE_API_KEY"] = @key if @key
  end

  test "enabled? is false and the key is empty without TYPESAFE_API_KEY" do
    assert_equal "", Jev.api_key
    refute Jev.enabled?
  end

  test "enabled? is true once the key is set" do
    ENV["TYPESAFE_API_KEY"] = "key"

    assert_equal "key", Jev.api_key
    assert Jev.enabled?
  end
end
