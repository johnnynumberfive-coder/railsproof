class Post < ApplicationRecord
  belongs_to :user

  validates :title, presence: true

  def title_matches?(query)
    return false if query.blank?

    title.to_s.downcase.include?(query.to_s.downcase)
  end
end
