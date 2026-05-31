# frozen_string_literal: true

module TrustedProxies
  module Cloudflare
    IPV4_URL = "https://www.cloudflare.com/ips-v4"
    IPV6_URL = "https://www.cloudflare.com/ips-v6"

    module_function

    def fetch_cidrs(connection: default_connection)
      v4 = fetch_list(connection, IPV4_URL)
      v6 = fetch_list(connection, IPV6_URL)
      v4 + v6
    end

    def fetch_list(connection, url)
      response = connection.get(url)
      unless response.success?
        raise "HTTP #{response.status} fetching #{url}"
      end

      response.body.lines.map(&:strip).reject(&:blank?)
    end

    def default_connection
      Faraday.new do |f|
        f.response :follow_redirects
        f.adapter Faraday.default_adapter
      end
    end
  end
end
