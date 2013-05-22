#encoding: utf-8
$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "catarse_moip/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "catarse_moip"
  s.version     = CatarseMoip::VERSION
  s.authors     = ["Antônio Roberto Silva"]
  s.email       = ["forevertonny@gmail.com"]
  s.homepage    = "http://github.com/devton/catarse_moip"
  s.summary     = "MoIP integration with Catarse"
  s.description = "MoIP integration with Catarse crowdfunding platform"

  s.files      = `git ls-files`.split($\)
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  s.add_dependency "rails", "~> 3.2.13"
  s.add_dependency('libxml-ruby', '~> 2.6.0')

  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "factory_girl_rails"
  s.add_development_dependency "database_cleaner"
end
