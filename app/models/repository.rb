class Repository < ApplicationRecord
  has_many :push_events, dependent: :destroy

  validates :github_id, presence: true, uniqueness: true
  validates :name, presence: true
end
