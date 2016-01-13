require 'cadre/simplecov'
require 'simplecon/json'
SimpleCov.start do
  coverage_dir "corundum/docs/coverage"
  add_filter "./spec"
  add_filter "vendor/bundle"

  formatter SimpleCov::Formatter::MultiFormatter[
    SimpleCov::Formatter::JSONFormatter,
    SimpleCov::Formatter::HTMLFormatter,
    Cadre::SimpleCov::VimFormatter
  ]
end
