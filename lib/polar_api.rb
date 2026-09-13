# frozen_string_literal: true

require "ostruct"

# HTTP client for Polar's documented API. Pins Polar-Version so requests do not
# silently follow Polar's floating Current version (see polar.sh docs on versioning).
module PolarApi
  VERSION = "2026-04"
  USER_AGENT = "ugo/polar-api (Polar-Version #{VERSION})"
  OPEN_TIMEOUT = 5
  TIMEOUT = 15

  class Error < StandardError
    attr_reader :status, :body

    def initialize(message, status: nil, body: nil)
      super(message)
      @status = status
      @body = body
    end
  end

  class << self
    # Faraday adapter override for tests, e.g. `[:test, stubs]`.
    attr_accessor :adapter

    def reset!
      @connection = nil
      @adapter = nil
    end

    def create_checkout(products:, success_url:, customer_email:, metadata:)
      post("/v1/checkouts/", {
        products: Array(products),
        success_url: success_url,
        customer_email: customer_email,
        metadata: metadata
      })
    end

    def create_customer_session(customer_id:, return_url:)
      post("/v1/customer-sessions/", {
        customer_id: customer_id,
        return_url: return_url
      })
    end

    def revoke_subscription(id)
      delete("/v1/subscriptions/#{id}")
    end

    private

    def post(path, body)
      parse_response(connection.post(path, body))
    rescue Faraday::Error => e
      raise Error, "Polar API request failed: #{e.message}"
    end

    def delete(path)
      parse_response(connection.delete(path))
      true
    rescue Faraday::Error => e
      raise Error, "Polar API request failed: #{e.message}"
    end

    def connection
      token = Polar.config.access_token
      raise Error, "Polar is not configured" if token.blank?

      @connection ||= Faraday.new(
        url: Polar.config.endpoint,
        headers: {
          "Authorization" => "Bearer #{token}",
          "Polar-Version" => VERSION,
          "Accept" => "application/json",
          "User-Agent" => USER_AGENT
        },
        request: { open_timeout: OPEN_TIMEOUT, timeout: TIMEOUT }
      ) do |f|
        f.request :json
        if adapter
          f.adapter(*Array(adapter))
        else
          f.adapter Faraday.default_adapter
        end
      end
    end

    def parse_response(response)
      unless response.success?
        raise Error.new("Polar API error (#{response.status})", status: response.status, body: response.body)
      end

      body = response.body
      body = JSON.parse(body) if body.is_a?(String) && body.present?
      body = {} if body.blank?
      OpenStruct.new(body.is_a?(Hash) ? body.deep_symbolize_keys : {})
    end
  end
end
