require 'activerecord_connector'
require File.join(File.dirname(__FILE__), '../fixtures/schema.rb')

module ActiverecordTestHelper
  FIXTURES_PATH = File.join(File.dirname(__FILE__), '/../fixtures')
  dep = defined?(ActiveSupport::Dependencies) ? ActiveSupport::Dependencies : ::Dependencies
  dep.autoload_paths.unshift FIXTURES_PATH
end