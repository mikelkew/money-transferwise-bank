# Money TransferWise Bank

[![Gem Version](https://badge.fury.io/rb/money-transferwise-bank.svg)](https://rubygems.org/gems/money-transferwise-bank)
[![Gem Downloads](https://img.shields.io/gem/dt/money-transferwise-bank.svg?maxAge=86400)](https://rubygems.org/gems/money-transferwise-bank)
[![Build Status](https://secure.travis-ci.org/mikelkew/money-transferwise-bank.svg?branch=master)](https://travis-ci.org/mikelkew/money-transferwise-bank)
[![Code Climate](https://api.codeclimate.com/v1/badges/2f2915f2fb539324fe3f/maintainability)](https://codeclimate.com/github/mikelkew/money-transferwise-bank)
[![Inline Docs](http://inch-ci.org/github/mikelkew/money-transferwise-bank.svg?branch=master)](http://inch-ci.org/github/mikelkew/money-transferwise-bank)
[![License](https://img.shields.io/github/license/mikelkew/money-transferwise-bank.svg)](http://opensource.org/licenses/MIT)

A gem that calculates the exchange rate using available rates from the [TransferWise](https://transferwise.com/) Exchange Rate API.

## TransferWise API

~~~ json
[
  /* 157 currencies */
  {
    "rate": 1.74145,
    "source": "USD",
    "target": "BGN",
    "time": "2019-06-05T17:48:33+0000"
  },
  {
    "rate": 1180.34,
    "source": "USD",
    "target": "KRW",
    "time": "2019-06-05T17:48:33+0000"
  },
  ...
]
~~~

Note that the TransferWise API is only available if you sign up for a free TransferWise account. See more information about their API in the [TransferWise API Documentation](https://api-docs.transferwise.com/#exchange-rates)

## Features

* supports 157 currencies
* precision of rates up to 6 digits after point
* uses fast and reliable JSON API
* average response time < 400ms
* supports caching currency rates
* calculates every pair rate calculating inverse rate or using base currency rate
* supports multiple server instances, thread safe

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'money-transferwise-bank'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install money-transferwise-bank

## Usage

~~~ ruby
# Minimal requirements
require 'money/bank/transferwise_bank'
mtwb = Money::Bank::TransferwiseBank.new
mtwb.access_key = 'your access_key from https://transferwise.com'

# Update rates (get new rates from remote if expired or access rates from cache)
mtwb.update_rates

# Force update rates from remote and store in cache
# mtwb.update_rates(true)

# (optional)
# Set the base currency for all rates. By default, USD is used.
mtwb.source = 'EUR'

# (optional)
# Set the seconds after than the current rates are automatically expired
# by default, they never expire, in this example 1 day.
mtwb.ttl_in_seconds = 86400

# (optional)
# Option to use the Sandbox version of the TransferWise API.
# By default, this is false and the live API is used.
mtwb.use_sandbox = true

# (optional)
# Option to raise an error on failure to connect to the API or parse
# the response. By default, this is true, but the ability to disable
# it is useful when developing without an active internet connection.
mtwb.raise_on_failure = false

# Define cache (string or pathname)
mtwb.cache = 'path/to/file/cache'

# Set money default bank to transferwise bank
Money.default_bank = mtwb
~~~

### More methods

~~~ ruby
mtwb = Money::Bank::TransferwiseBank.new

# Returns the base currency set for all rates.
mtwb.source

# Expires rates if the expiration time is reached.
mtwb.expire_rates!

# Returns true if the expiration time is reached.
mtwb.expired?

# Get the API source url.
mtwb.source_url

# Get the rates timestamp of the last API request.
mtwb.rates_timestamp

# Get the rates timestamp of loaded rates in memory.
moxb.rates_mem_timestamp
~~~

### How to exchange

~~~ ruby
# Exchange 1000 cents (10.0 USD) to EUR
Money.new(1000, 'USD').exchange_to('EUR')        # => #<Money fractional:89 currency:EUR>
Money.new(1000, 'USD').exchange_to('EUR').to_f   # => 8.9

# Format
Money.new(1000, 'USD').exchange_to('EUR').format # => €8.90

# Get the rate
Money.default_bank.get_rate('USD', 'CAD')        # => 0.9
~~~

See more on https://github.com/RubyMoney/money.

### Using gem money-rails

You can also use it in Rails with the gem [money-rails](https://github.com/RubyMoney/money-rails).

~~~ ruby
require 'money/bank/transferwise_bank'

MoneyRails.configure do |config|
  mtwb = Money::Bank::TransferwiseBank.new
  mtwb.access_key = 'your access_key from https://transferwise.com/product'
  mtwb.update_rates

  config.default_bank = mtwb
end
~~~

### Cache

You can also provide a Proc as a cache to provide your own caching mechanism
perhaps with Redis or just a thread safe `Hash` (global). For example:

~~~ ruby
mtwb.cache = Proc.new do |v|
  key = 'money:transferwise_bank'
  if v
    Thread.current[key] = v
  else
    Thread.current[key]
  end
end
~~~

## Process

The gem fetches all rates in a cache with USD as base currency. It's possible to compute the rate between any of the currencies by calculating a pair rate using base USD rate.

## Tests

You can place your own key on a file or environment
variable named TEST_ACCESS_KEY and then run:

~~~
bundle exec rake
~~~

## Refs

* Gem [money](https://github.com/RubyMoney/money)
* Gem [money-currencylayer-bank](https://github.com/phlegx/money-currencylayer-bank)
* Gem [money-openexchangerates-bank](https://github.com/phlegx/money-openexchangerates-bank)
* Gem [money-historical-bank](https://github.com/atwam/money-historical-bank)

## Other Implementations

* Gem [currencylayer](https://github.com/askuratovsky/currencylayer)
* Gem [money-openexchangerates-bank](https://github.com/phlegx/money-openexchangerates-bank)
* Gem [money-open-exchange-rates](https://github.com/spk/money-open-exchange-rates)
* Gem [money-historical-bank](https://github.com/atwam/money-historical-bank)
* Gem [eu_central_bank](https://github.com/RubyMoney/eu_central_bank)
* Gem [nordea](https://github.com/matiaskorhonen/nordea)
* Gem [google_currency](https://github.com/RubyMoney/google_currency)

## Contributors

* See [github.com/mikelkew/money-transferwise-bank](https://github.com/mikelkew/money-transferwise-bank/graphs/contributors).
* Inspired by [github.com/phlegx/money-currencylayer-bank](https://github.com/phlegx/money-currencylayer-bank/graphs/contributors).

## Contributing

1. Fork it ( https://github.com/[your-username]/money-transferwise-bank/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

The MIT License

Copyright (c) 2019 Mikel Kew
