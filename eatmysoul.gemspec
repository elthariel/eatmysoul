# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "eatmysoul/version"

Gem::Specification.new do |s|
  s.name        = "eatmysoul"
  s.version     = Eatmysoul::VERSION
  s.authors     = ["Julien 'Lta' BALLET"]
  s.email       = ["ballet_j@epitech.eu"]
  s.homepage    = "http://github.com/elthariel/eatmysoul"
  s.summary     = "Simple chatless netsoul client"
  s.description = "A simple netsoul (epitech's internal network protocol) client, mainly targeting servers"

  s.rubyforge_project = "eatmysoul"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  s.add_runtime_dependency "eventmachine"
  s.add_runtime_dependency "daemons"
end
