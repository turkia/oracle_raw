# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "oracle_raw"
  gem.homepage = "http://github.com/opiskelijarekisteri-devel/oracle_raw"
  gem.license = "MIT"
  gem.summary = %Q{Ruby library for interfacing with an Oracle Database using pooled OCI8 raw connections.}
  gem.description = %Q{This is a Ruby library for interfacing with an Oracle Database using pooled OCI8 raw connections (http://ruby-oci8.rubyforge.org/en/). Connection pooling is achieved by utilizing ActiveRecord Oracle Enhanced adapter (https://github.com/rsim/oracle-enhanced).}
  gem.email = "opiskelijarekisteri-devel@helsinki.fi"
  gem.authors = ["opiskelijarekisteri-devel"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

require 'rcov/rcovtask'
Rcov::RcovTask.new do |test|
  test.libs << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
  test.rcov_opts << '--exclude "gems/*"'
end

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "oracle_raw #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
