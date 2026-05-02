class Rotation < ApplicationRecord
  belongs_to :user
  has_many :rotation_items, -> { order(:position) }, dependent: :destroy
  has_many :watch_items, through: :rotation_items

  validates :name, presence: true

  scope :active, -> { where(active: true) }

  def service
    RotationService.new(self)
  end
end
