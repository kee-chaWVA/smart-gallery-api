class AddTagsAndEmbeddingToPhotos < ActiveRecord::Migration[8.1]
  def change
    enable_extension "vector"

    add_column :photos, :tags, :string, array: true, default: [], null: false
    add_index :photos, :tags, using: :gin

    # CLIP ViT-B/32 image embeddings have 512 dimensions
    add_column :photos, :embedding, :vector, limit: 512
  end
end
