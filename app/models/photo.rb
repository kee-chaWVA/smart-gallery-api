class Photo < ApplicationRecord
  has_one_attached :image
  has_neighbors :embedding

  validates :filename, presence: true
  validates :file_path, presence: true, uniqueness: true
end
