# -*- encoding: utf-8 -*-
require File.expand_path("../lib/capistrano-resque/version", __FILE__)

Gem::Specification.new do |gem|
  gem.name        = "capistrano-supervisor-resque"
  gem.version     = CapistranoSupervisorResque::VERSION.dup
  gem.author      = "Alex Willemsma"
  gem.email       = "alex@alexwillemsma.com"
  gem.homepage    = "https://github.com/undergroundwebdesigns/capistrano-supervisor-resque"
  gem.summary     = %q{Supervisord controlled Resque integration for Capistrano}
  gem.description = %q{Capistrano plugin that integrates Resque server tasks for when resque workers are maanged by Supervisord.}

  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables   = `git ls-files -- bin/*`.split("\n").map{|f| File.basename(f)}
  gem.require_paths = ["lib"]

  gem.add_runtime_dependency "capistrano"
  gem.add_runtime_dependency "resque"
  gem.add_runtime_dependency "resque-scheduler"
end
