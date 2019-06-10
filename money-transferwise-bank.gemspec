# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = 'money-transferwise-bank'
  s.version = '0.1.2'
  s.date = Time.now.utc.strftime('%Y-%m-%d')
  s.homepage = "http://github.com/mikelkew/#{s.name}"
  s.authors = ['Mikel Kew']
  s.email = 'mikel.j.kew@gmail.com'
  s.description = 'A gem that calculates the exchange rate using available ' \
    'rates from TransferWise. Compatible with the money gem.'
  s.summary = 'A gem that calculates the exchange rate using available rates ' \
    'from TransferWise.'
  s.extra_rdoc_files = %w[README.md]
  s.files = Dir['LICENSE', 'README.md', 'Gemfile', 'lib/**/*.rb',
                'test/**/*']
  s.license = 'MIT'
  s.test_files = Dir.glob('test/*_test.rb')
  s.require_paths = ['lib']
  s.required_ruby_version = '>= 2.0.0'
  s.rubygems_version = '1.3.7'
  s.add_dependency 'httparty', '~> 0.17'
  s.add_dependency 'json', '>= 1.7'
  s.add_dependency 'monetize', '~> 1.7'
  s.add_dependency 'money', '~> 6.9'
  s.add_development_dependency 'inch', '~> 0.8'
  s.add_development_dependency 'minitest', '~> 5.11'
  s.add_development_dependency 'minitest-line', '~> 0.6'
  s.add_development_dependency 'rake', '~> 12.3'
  s.add_development_dependency 'rr', '~> 1.2'
  s.add_development_dependency 'rubocop', '~> 0.50.0'
  s.add_development_dependency 'simplecov', '~> 0.16'
  s.add_development_dependency 'timecop', '~> 0.9'
end
