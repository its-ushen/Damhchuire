require "securerandom"

class ActionInvocation < ApplicationRecord
  self.primary_key = :id

  STATUSES = %w[
    received
    running
    succeeded
    failed
    callback_sent
    callback_failed
  ].freeze

  belongs_to :action,
    foreign_key: :action_slug,
    primary_key: :slug,
    inverse_of: :action_invocations,
    optional: true

  before_validation :assign_id, on: :create

  validates :id, presence: true
  validates :chain_request_id, presence: true
  validates :chain_tx_signature, presence: true
  validates :action_slug, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :chain_request_id, uniqueness: { scope: :chain_tx_signature }

  scope :recent_first, -> { order(created_at: :desc) }

  def transition_to!(new_status, **attrs)
    raise ArgumentError, "invalid status: #{new_status}" unless STATUSES.include?(new_status)

    update!(attrs.merge(status: new_status))
  end

  private

  def assign_id
    self.id ||= SecureRandom.uuid
  end
end
