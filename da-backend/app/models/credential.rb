class Credential < ApplicationRecord
  encrypts :value

  validates :name,
    presence: true,
    uniqueness: true,
    format: { with: /\A[a-zA-Z0-9_]+\z/, message: "only letters, digits, and underscores" }
  validates :value, presence: true

  def self.values_hash
    all.each_with_object({}) do |cred, hash|
      hash[cred.name] = cred.value
    end
  end
end
