class Actor < ApplicationRecord
  has_many :push_events, dependent: :destroy
  has_one_attached :avatar

  validates :github_id, presence: true, uniqueness: true
  validates :login, presence: true
end
