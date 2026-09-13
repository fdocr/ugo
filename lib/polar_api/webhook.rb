# frozen_string_literal: true

require "ostruct"

module PolarApi
  class Webhook
    class VerificationError < StandardError; end

    TOLERANCE_SECONDS = 5 * 60
    Event = Struct.new(:type, :object, :api_version, keyword_init: true)

    class << self
      def verify(request)
        secret = Polar.config.webhook_secret.to_s
        raise VerificationError, "No webhook secret configured" if secret.blank?

        payload = request.raw_post.to_s
        verify_signature!(payload, request.headers, secret)

        parsed = JSON.parse(payload, symbolize_names: true)
        Event.new(
          type: parsed[:type],
          object: OpenStruct.new(parsed[:data] || {}),
          api_version: parsed[:api_version].presence || header(request.headers, "webhook-api-version")
        )
      end

      private

      def verify_signature!(payload, headers, secret)
        webhook_id = header(headers, "webhook-id")
        timestamp = header(headers, "webhook-timestamp")
        signatures = header(headers, "webhook-signature")
        if webhook_id.blank? || timestamp.blank? || signatures.blank?
          raise VerificationError, "Missing required headers"
        end

        ts = Integer(timestamp)
        now = Time.now.to_i
        raise VerificationError, "Message timestamp too old" if ts < now - TOLERANCE_SECONDS
        raise VerificationError, "Message timestamp too new" if ts > now + TOLERANCE_SECONDS

        signed_content = "#{webhook_id}.#{ts}.#{payload}"
        matching = signatures.split.any? do |versioned|
          version, encoded = versioned.split(",", 2)
          next false unless version == "v1" && encoded.present?

          decoded = decode64(encoded)
          next false if decoded.nil?

          signing_keys(secret).any? do |key|
            expected = OpenSSL::HMAC.digest("SHA256", key, signed_content)
            secure_compare(expected, decoded)
          end
        end

        raise VerificationError, "No matching signature found" unless matching
      rescue ArgumentError
        raise VerificationError, "Invalid signature headers"
      end

      # Polar HMAC (pre-2026-09-08 secrets): UTF-8 bytes of the full secret.
      # Standard Webhooks (newer secrets): base64-decode the part after `whsec_`.
      def signing_keys(secret)
        keys = [ secret.encode("UTF-8") ]
        decoded = decode_standard_webhooks_key(secret)
        keys << decoded if decoded.present? && decoded != keys.first
        keys
      end

      def decode_standard_webhooks_key(secret)
        remainder = secret.delete_prefix("whsec_")
        decode64(remainder)
      end

      def decode64(value)
        padded = value + ("=" * ((4 - value.length % 4) % 4))
        Base64.strict_decode64(padded)
      rescue ArgumentError
        nil
      end

      def header(headers, name)
        headers[name]
      end

      def secure_compare(a, b)
        return false unless a.bytesize == b.bytesize
        ActiveSupport::SecurityUtils.fixed_length_secure_compare(a, b)
      end
    end
  end
end
