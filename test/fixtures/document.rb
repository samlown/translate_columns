class Document < ActiveRecord::Base
  include TranslateColumns

  has_many :translations, :class_name => 'DocumentTranslation'
  translate_columns :title, :body

  validates :title, :presence => true, :length => { :in => 3..200 }
  validates :body, :length => { :in => 3..500 }

end