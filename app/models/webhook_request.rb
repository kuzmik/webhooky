class WebhookRequest < ApplicationRecord
  self.primary_key = "uuid"

  belongs_to :token, foreign_key: :token_id, primary_key: :uuid

  before_create :generate_uuid

  validates :method_name, presence: true
  validates :url, presence: true
  validates :ip, presence: true

  private

  def generate_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
