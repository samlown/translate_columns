
require 'test/lib/activerecord_connector'
require 'test/fixtures/schema.rb'

module ActiverecordTestHelper
  FIXTURES_PATH = File.join(File.dirname(__FILE__), '/../fixtures')
  dep = defined?(ActiveSupport::Dependencies) ? ActiveSupport::Dependencies : ::Dependencies
  dep.load_paths.unshift FIXTURES_PATH
end

