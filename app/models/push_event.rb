class PushEvent < ApplicationRecord
  belongs_to :actor
  belongs_to :repository

  validates :github_id, presence: true, uniqueness: true
  validates :ref, presence: true
  validates :head, presence: true
  validates :before, presence: true
  validates :raw_payload, presence: true
end
