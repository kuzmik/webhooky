class Token < ApplicationRecord
  self.primary_key = "uuid"

  has_many :webhook_requests, foreign_key: :token_id, dependent: :destroy

  before_create :generate_uuid

  validates :default_status, numericality: { only_integer: true, greater_than_or_equal_to: 100, less_than_or_equal_to: 599 }
  validates :timeout, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 10 }, allow_nil: true

  private

  def generate_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
