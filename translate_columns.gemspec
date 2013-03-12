# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{translate_columns}
  s.version = File.read(File.join(File.dirname(__FILE__), 'VERSION')).strip

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.5") if s.respond_to? :required_rubygems_version=
  s.authors = ["Sam Lown"]
  s.date = %q{2011-01-21}
  s.description = %q{Automatically translate ActiveRecord columns using a second model containing the translations.}
  s.email = %q{me@samlown.com}
  s.extra_rdoc_files = [
    "LICENSE",
    "README.rdoc"
  ]
  s.homepage = %q{http://github.com/samlown/translate_columns}
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{Use fields from other translation models easily}
  
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_paths = ["lib"]
  
  s.add_dependency("activerecord", "~> 3.2.12")
  s.add_development_dependency("rake", "~> 10.0.3")
  s.add_development_dependency("mocha", "~> 0.13.3")
  s.add_development_dependency("sqlite3", "~> 1.3.7")
end