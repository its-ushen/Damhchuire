require "test_helper"

class CredentialTest < ActiveSupport::TestCase
  test "validates name presence" do
    cred = Credential.new(value: "secret")
    assert_not cred.valid?
    assert_includes cred.errors[:name], "can't be blank"
  end

  test "validates name uniqueness" do
    Credential.create!(name: "api_key", value: "secret1")
    dup = Credential.new(name: "api_key", value: "secret2")
    assert_not dup.valid?
    assert_includes dup.errors[:name], "has already been taken"
  end

  test "validates name format rejects dots" do
    cred = Credential.new(name: "api.key", value: "secret")
    assert_not cred.valid?
  end

  test "validates name format rejects hyphens" do
    cred = Credential.new(name: "api-key", value: "secret")
    assert_not cred.valid?
  end

  test "validates name format accepts underscores" do
    cred = Credential.new(name: "my_api_key", value: "secret")
    assert cred.valid?
  end

  test "validates value presence" do
    cred = Credential.new(name: "api_key")
    assert_not cred.valid?
    assert_includes cred.errors[:value], "can't be blank"
  end

  test ".values_hash returns name to value mapping" do
    Credential.create!(name: "key_a", value: "val_a")
    Credential.create!(name: "key_b", value: "val_b")

    hash = Credential.values_hash
    assert_equal "val_a", hash["key_a"]
    assert_equal "val_b", hash["key_b"]
  end
end
