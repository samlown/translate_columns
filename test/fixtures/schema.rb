ActiveRecord::Schema.define do
  create_table "documents", :force => true do |t|
    t.column "locale", :string, :length => 8
    t.column "title", :string
    t.column "body",  :text
    t.column "published_at", :datetime
    t.timestamps
  end

  create_table "document_translations", :force => true do |t|
    t.references "document"
    t.string :locale
    t.column "title", :string
    t.column "body", :text
    t.timestamps
  end
end

