require 'test/lib/activerecord_test_helper'
require 'test/unit'
require 'mocha'
require 'init'

class TranslateColumnsTest < Test::Unit::TestCase 

  include ActiverecordTestHelper

  def setup
    @docs = Fixtures.create_fixtures(FIXTURES_PATH, ['documents', 'document_translations'])
  end

  def teardown
    Fixtures.reset_cache
  end

  def test_basic_document_fields
    doc = Document.find(:first)
    assert_equal "Test Document Number 1", doc.title, "Document not found!"
    assert_not_nil doc.body, "Empty document body"
    assert_not_nil doc.published_at, "Missing published date"
  end

  def test_basic_document_fields_for_default_locale
    I18n.locale = "en"
    doc = Document.find(:first)
    assert_equal "Test Document Number 1", doc.title, "Document not found!"
    assert_not_nil doc.body, "Empty document body"
    assert_not_nil doc.published_at, "Missing published date"
  end

  def test_count_translations
    doc = Document.find(:first)
    assert_equal 2, doc.translations.count, "Count doesn't match!"
  end

  def test_basic_document_fields_for_spanish
    I18n.locale = "es"
    doc = Document.find(:first)
    assert_equal "Este es el titulo de un documento en Espa\303\261ol", doc.title, "Document not found!"
    assert_equal "Nada", doc.body, "Different document body"
    assert_not_nil doc.published_at, "Missing published date"
    assert_equal "Test Document Number 1", doc.title_before_translation
  end

  def test_missing_fields_resort_to_original
    I18n.locale = 'fr'
    doc = Document.find(:first)
    assert_equal "Un title en francais", doc.title
    assert_match /body/, doc.body
    assert doc.body_before_type_cast.to_s.empty?
  end

  def test_switching_languages_for_reading
    I18n.locale = I18n.default_locale
    doc1 = Document.find(:first)
    assert_equal "Test Document Number 1", doc1.title 
    I18n.locale = 'es'
    doc2 = Document.find(:first)
    assert_equal doc1.title, doc2.title
    assert_not_equal "Test Document Number 1", doc1.title 
    I18n.locale = 'en'
    assert_equal doc1.title, doc2.title
    assert_equal "Test Document Number 1", doc1.title 
  end

  def test_setting_fields_in_default_language
    time_now = Time.now
    I18n.locale = I18n.default_locale
    doc1 = Document.find(:first)
    doc1.title = "A new title"
    doc1.published_at = time_now
    assert doc1.save, "Unable to save document"
    assert_equal "A new title", doc1.title
    # Now change language
    I18n.locale = 'es'
    doc1 = Document.find(:first)
    assert_not_equal "A new title", doc1.title
    assert_equal time_now.to_s, doc1.published_at.to_s
  end

  def test_saving_changes_in_translations
    time_now = Time.now
    I18n.locale = 'es'
    doc1 = Document.find(:first)
    doc1.title = "Un nuevo título"
    doc1.published_at = time_now
    assert doc1.save
    I18n.locale = I18n.default_locale
    doc1 = Document.find(:first)
    assert_not_equal "Un nuevo título", doc1.title
    assert_equal time_now.to_s, doc1.published_at.to_s
  end

  def test_creating_new_documents
    I18n.locale = I18n.default_locale 
    doc = Document.new(:title => "A new document", :body => "The Body")
    assert doc.save
  end

  def test_creating_new_documents_under_locale_fails
    I18n.locale = 'es' 
    assert_raise TranslateColumns::MissingParent do
      Document.new(:title => "Un nuevo documento", :body => 'El cuerpo')
    end
  end

  def test_failed_validations
    I18n.locale = I18n.default_locale
    doc = Document.find(:first)
    doc.title = "a"
    assert !doc.save
    assert doc.errors.on(:title)
  end

  def test_failed_validations_on_translation
    I18n.locale = 'es'
    doc = Document.find(:first)
    doc.title = "a"
    assert !doc.save
    assert doc.errors.on(:title)
  end

  def test_locale_attribute_detection
    doc = Document.find(:first)
    assert !doc.has_locale_value?
    doc.locale = "en"
    assert doc.has_locale_value?
  end

  def test_locale_attribute_detection_without_attribute
    doc = Document.find(:first)
    doc.locale = "en"
    doc.stubs(:respond_to?).with(:locale).returns(false)
    assert !doc.has_locale_value?
  end

  def test_create_new_document_with_specific_locale
    I18n.locale = 'es'
    doc = nil
    assert_nothing_thrown do
      doc = Document.new(:locale => 'es', :title => "A new document", :body => "Test Body")
    end
    assert doc.locale, 'es'
    assert doc.save
  end
  
end
