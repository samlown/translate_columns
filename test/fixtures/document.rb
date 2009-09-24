class Document < ActiveRecord::Base
  
  has_many :translations, :class_name => 'DocumentTranslation'
  translate_columns :title, :body

  validates_presence_of :title
  validates_length_of :title, :within => 3..200

  validates_length_of :body, :within => 3..500
end
