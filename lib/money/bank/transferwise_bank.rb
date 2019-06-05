# frozen_string_literal: true

require 'money'
require 'json'
# require 'open-uri'
require 'httparty'

# Money gem class
class Money
  # Build in memory rates store
  module RatesStore
    # Memory class
    class Memory
      # Add method to reset the build in memory store
      # @param [Hash] rates Optional initial exchange rate data.
      # @return [Object] store.
      def reset!(rates = {})
        transaction { @index = rates }
      end
    end
  end

  # https://github.com/RubyMoney/money#exchange-rate-stores
  module Bank
    # Invalid cache, file not found or cache empty
    class InvalidCache < StandardError; end

    # App id not set error
    class NoAccessKey < StandardError; end

    # TransferwiseBank base class
    class TransferwiseBank < Money::Bank::VariableExchange
      # TransferwiseBank url components
      TW_SERVICE_HOST = 'api.transferwise.com'
      TW_SERVICE_PATH = '/v1/rates'

      TW_SANDBOX_SERVICE_HOST = 'api.sandbox.transferwise.tech'

      # Default SSL Version
      TW_SERVICE_SSL_VERSION = :TLSv1_2

      # Default base currency
      TW_SOURCE = 'USD'

      attr_accessor :service_path
      attr_accessor :service_ssl_version

      # API must have a valid access_key
      #
      # @param value [String] API access key
      # @return [String] chosen API access key
      attr_accessor :access_key

      # Cache accessor, can be a String or a Proc
      #
      # @param value [String,Pathname,Proc] cache system
      # @return [String,Pathname,Proc] chosen cache system
      attr_accessor :cache

      # Parsed TransferwiseBank result as Hash
      attr_reader :rates

      # Get the timestamp of rates in memory
      # @return [Time] time object or nil
      attr_reader :rates_mem_timestamp

      # Set the seconds after than the current rates are automatically expired
      # by default, they never expire.
      #
      # @example
      #   ttl_in_seconds = 86400 # will expire the rates in one day
      #
      # @param value [Integer] time to live in seconds
      # @return [Integer] chosen time to live in seconds
      attr_writer :ttl_in_seconds

      # Set the SSL Version used for requests to the API.
      # By default, :TLSv1_2 is used.
      #
      # @example
      #   service_ssl_version = :TLSv1_1
      #
      # @param value [Symbol] SSL version from OpenSSL::SSL::SSLContext::METHODS
      # @return [Symbol] chosen SSL version
      attr_writer :service_ssl_version

      # Option to use the Sandbox version of the TransferWise API.
      # By default, this is false, and the live API is used.
      #
      # @example
      #   use_sandbox = true
      #
      # @param value [Boolean] should the sandbox api be used?
      # @return [Boolean] is the sandbox api being used?
      attr_writer :use_sandbox

      # Option to raise an error on failure to connect to the API or parse
      # the response. By default, this is true, but the ability to disable
      # it is useful when developing without an active internet connection.
      #
      # @example
      #   raise_on_failure = false
      #
      # @param value [Boolean] should an error be raised on API failure?
      # @return [Boolean] is an error to be raised on API failure?
      attr_writer :raise_on_failure

      # Set the base currency for all rates. By default, USD is used.
      # TransferwiseBank only allows USD as base currency
      # for the free plan users.
      #
      # @example
      #   source = 'USD'
      #
      # @param value [String] Currency code, ISO 3166-1 alpha-3
      # @return [String] chosen base currency
      def source=(value)
        @source = Money::Currency.find(value.to_s).try(:iso_code) || TW_SOURCE
      end

      # Get the base currency for all rates. By default, USD is used.
      # @return [String] base currency
      def source
        @source ||= TW_SOURCE
      end

      # Get the seconds after than the current rates are automatically expired
      # by default, they never expire.
      # @return [Integer] chosen time to live in seconds
      def ttl_in_seconds
        @ttl_in_seconds ||= 0
      end

      # Set the SSL Version used for requests to the API.
      # By default, :TLSv1_2 is used.
      # @return [Symbol] chosen SSL version
      def service_ssl_version
        @service_ssl_version ||= TW_SERVICE_SSL_VERSION
      end

      # Option to use the Sandbox version of the TransferWise API.
      # By default, this is false, and the live API is used.
      # @return [Boolean] is the sandbox api being used?
      def use_sandbox
        @use_sandbox = false if @use_sandbox.nil?
        @use_sandbox
      end

      # Option to raise an error on failure to connect to the API or parse
      # the response. By default, this is true, but the ability to disable
      # it is useful when developing without an active internet connection.
      # @return [Boolean] is an error to be raised on API failure?
      def raise_on_failure
        @raise_on_failure = true if @raise_on_failure.nil?
        @raise_on_failure
      end

      # Update all rates from TrasferwiseBank JSON
      # @return [Array] array of exchange rates
      def update_rates(straight = false)
        new_rates = exchange_rates(straight)
        return if new_rates.first.empty?
        store.reset!
        rates = new_rates.each do |exchange_rate|
          currency = exchange_rate['target']
          rate = exchange_rate['rate']
          next unless Money::Currency.find(currency)
          add_rate(source, currency, rate)
          add_rate(currency, source, 1.0 / rate)
        end
        @rates_mem_timestamp = rates_timestamp
        rates
      end

      # Override Money `add_rate` method for caching
      # @param [String] from_currency Currency ISO code. ex. 'USD'
      # @param [String] to_currency Currency ISO code. ex. 'CAD'
      # @param [Numeric] rate Rate to use when exchanging currencies.
      # @return [Numeric] rate.
      def add_rate(from_currency, to_currency, rate)
        super
      end

      # Alias super method
      alias super_get_rate get_rate

      # Override Money `get_rate` method for caching
      # @param [String] from_currency Currency ISO code. ex. 'USD'
      # @param [String] to_currency Currency ISO code. ex. 'CAD'
      # @param [Hash] opts Options hash to set special parameters.
      # @return [Numeric] rate.
      def get_rate(from_currency, to_currency, opts = {})
        expire_rates!
        rate = get_rate_or_calc_inverse(from_currency, to_currency, opts)
        rate || calc_pair_rate_using_base(from_currency, to_currency, opts)
      end

      # Fetch new rates if cached rates are expired or stale
      # @return [Boolean] true if rates are expired and updated from remote
      def expire_rates!
        if expired?
          update_rates(true)
          true
        elsif stale?
          update_rates
          true
        else
          false
        end
      end

      # Check if rates are expired
      # @return [Boolean] true if rates are expired
      def expired?
        Time.now > rates_expiration
      end

      # Check if rates are stale
      # Stale is true if rates are updated straight by another thread.
      # The actual thread has always old rates in memory store.
      # @return [Boolean] true if rates are stale
      def stale?
        rates_timestamp != rates_mem_timestamp
      end

      # Service host of TransferwiseBank API based on value
      # of 'use_sandbox' option.
      # @return [String] the remote API service host
      def service_host
        use_sandbox ? TW_SANDBOX_SERVICE_HOST : TW_SERVICE_HOST
      end

      # Source url of TransferwiseBank
      # @return [String] the remote API url
      def source_url
        raise NoAccessKey if access_key.nil? || access_key.empty?
        url_componenets = {
          host: service_host,
          path: TW_SERVICE_PATH,
          query: "source=#{source}"
        }
        URI::HTTPS.build(url_componenets)
      end

      # Get rates expiration time based on ttl
      # @return [Time] rates expiration time
      def rates_expiration
        rates_timestamp + ttl_in_seconds
      end

      # Get the timestamp of rates from first listed rate
      # @return [Time] time object or nil
      def rates_timestamp
        raw = raw_rates_careful
        raw.first.key?('time') ? Time.parse(raw.first['time']) : Time.at(0)
      end

      protected

      # Store the provided text data by calling the proc method provided
      # for the cache, or write to the cache file.
      #
      # @example
      #   store_in_cache("{\"quotes\": {\"USDAED\": 3.67304}}")
      #
      # @param text [String] parsed JSON content
      # @return [String,Integer]
      def store_in_cache(text)
        if cache.is_a?(Proc)
          cache.call(text)
        elsif cache.is_a?(String) || cache.is_a?(Pathname)
          write_to_file(text)
        end
      end

      # Writes content to file cache
      # @param text [String] parsed JSON content
      # @return [String,Integer]
      def write_to_file(text)
        open(cache, 'w') do |f|
          f.write(text)
        end
      rescue Errno::ENOENT
        raise InvalidCache
      end

      # Read from cache when exist
      # @return [Proc,String] parsed JSON content
      def read_from_cache
        if cache.is_a?(Proc)
          cache.call(nil)
        elsif (cache.is_a?(String) || cache.is_a?(Pathname)) &&
              File.exist?(cache)
          open(cache).read
        end
      end

      # Get remote content and store in cache
      # @return [String] unparsed JSON content
      def read_from_url
        rates = retrieve_rates
        store_in_cache(rates) if valid_rates?(rates) && cache
        rates
      end

      # Opens an url and reads the content
      # @return [String] unparsed JSON content
      def retrieve_rates
        response = HTTParty.get(
          source_url,
          headers: { 'Authorization' => "Bearer #{access_key}" },
          ssl_version: service_ssl_version
        )
        response.body
      rescue HTTParty::Error, SocketError => e
        raise e if raise_on_failure
        [{}]
      end

      # Check validity of rates response only for store in cache
      #
      # @example
      #   valid_rates?("{\"quotes\": {\"USDAED\": 3.67304}}")
      #
      # @param [String] text is JSON content
      # @return [Boolean] valid or not
      def valid_rates?(text)
        parsed = JSON.parse(text)
        parsed && parsed.is_a?(Array) && !parsed.first.empty?
      rescue JSON::ParserError, TypeError
        false
      end

      # Get exchange rates with different strategies
      #
      # @example
      #   exchange_rates(true)
      #   exchange_rates
      #
      # @param straight [Boolean] true for straight, default is careful
      # @return [Hash] key is country code (ISO 3166-1 alpha-3) value Float
      def exchange_rates(straight = false)
        @rates = if straight
                   raw_rates_straight
                 else
                   raw_rates_careful
                 end
      end

      # Get raw exchange rates from cache and then from url
      # @param rescue_straight [Boolean] true for rescue straight, default true
      # @return [String] JSON content
      def raw_rates_careful(rescue_straight = true)
        JSON.parse(read_from_cache.to_s)
      rescue JSON::ParserError, TypeError
        rescue_straight ? raw_rates_straight : [{}]
      end

      # Get raw exchange rates from url
      # @return [String] JSON content
      def raw_rates_straight
        JSON.parse(read_from_url)
      rescue JSON::ParserError, TypeError
        raw_rates_careful(false)
      end

      # Get rate or calculate it as inverse rate
      # @param [String] from_currency Currency ISO code. ex. 'USD'
      # @param [String] to_currency Currency ISO code. ex. 'CAD'
      # @return [Numeric] rate or rate calculated as inverse rate.
      def get_rate_or_calc_inverse(from_currency, to_currency, opts = {})
        rate = super_get_rate(from_currency, to_currency, opts)
        unless rate
          # Tries to calculate an inverse rate
          inverse_rate = super_get_rate(to_currency, from_currency, opts)
          if inverse_rate
            rate = 1.0 / inverse_rate
            add_rate(from_currency, to_currency, rate)
          end
        end
        rate
      end

      # Tries to calculate a pair rate using base currency rate
      # @param [String] from_currency Currency ISO code. ex. 'USD'
      # @param [String] to_currency Currency ISO code. ex. 'CAD'
      # @return [Numeric] rate or nil if cannot calculate rate.
      def calc_pair_rate_using_base(from_currency, to_currency, opts = {})
        from_base_rate = get_rate_or_calc_inverse(source, from_currency, opts)
        to_base_rate   = get_rate_or_calc_inverse(source, to_currency, opts)
        if to_base_rate && from_base_rate
          rate = to_base_rate / from_base_rate
          add_rate(from_currency, to_currency, rate)
          return rate
        end
        nil
      end
    end
  end
end
