$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "drbarpg/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "drbarpg"
  s.version     = Drbarpg::VERSION
  s.authors     = ["Lars Kanis"]
  s.email       = ["kanis@comcard.de"]
  s.homepage    = "http://github.com/larskanis/drbarpg"
  s.summary     = "Use DRb through your PostgreSQL server connection"
  s.description = "This gem implements a DRb protocol using PostgreSQL's LISTEN/NOTIFY event system."

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", ">= 3.0"
  s.add_dependency "pg"
end
