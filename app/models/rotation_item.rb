class RotationItem < ApplicationRecord
  belongs_to :rotation
  belongs_to :watch_item

  validates :position,          presence: true, numericality: { greater_than: 0 }
  validates :episodes_per_turn, presence: true, numericality: { greater_than: 0 }, inclusion: { in: 1..5 }

  default_scope { order(:position) }
end
