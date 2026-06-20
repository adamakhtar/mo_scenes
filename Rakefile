# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test_minitest) do |t|
  t.libs << "spec"
  t.libs << "lib"
  t.test_files = FileList["spec/*_spec.rb", "spec/minitest/**/*_spec.rb"]
end

desc "Run RSpec integration specs"
task :test_rspec do
  sh "bundle exec rspec spec/rspec"
end

task test: %i[test_minitest test_rspec]
task default: :test
