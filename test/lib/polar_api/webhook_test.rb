require "test_helper"

class PolarApiWebhookTest < ActiveSupport::TestCase
  HMAC_SECRET = "polar-hmac-secret"
  STANDARD_KEY = "standard-webhook-key"
  STANDARD_SECRET = "whsec_#{Base64.strict_encode64(STANDARD_KEY)}"

  test "accepts Polar HMAC signatures (UTF-8 bytes of the full secret)" do
    event = verify_payload(secret: HMAC_SECRET, key: HMAC_SECRET.encode("UTF-8"))

    assert_equal "order.paid", event.type
    assert_equal "ord_1", event.object.id
    assert_equal "2026-04", event.api_version
  end

  test "accepts Standard Webhooks signatures (base64 key after whsec_)" do
    event = verify_payload(secret: STANDARD_SECRET, key: STANDARD_KEY)

    assert_equal "order.paid", event.type
    assert_equal "ord_1", event.object.id
  end

  test "accepts Polar HMAC for a whsec_ secret as well" do
    event = verify_payload(secret: STANDARD_SECRET, key: STANDARD_SECRET.encode("UTF-8"))

    assert_equal "order.paid", event.type
  end

  test "rejects a bad signature" do
    error = assert_raises(PolarApi::Webhook::VerificationError) do
      verify_payload(secret: HMAC_SECRET, signature: "v1,#{Base64.strict_encode64("nope")}")
    end
    assert_match(/matching signature/i, error.message)
  end

  test "rejects missing webhook headers" do
    Polar.configure { |c| c.webhook_secret = HMAC_SECRET }
    request = OpenStruct.new(raw_post: { type: "order.paid" }.to_json, headers: {})

    error = assert_raises(PolarApi::Webhook::VerificationError) do
      PolarApi::Webhook.verify(request)
    end
    assert_match(/missing required headers/i, error.message)
  end

  test "rejects an empty webhook secret" do
    Polar.configure { |c| c.webhook_secret = "" }
    request = OpenStruct.new(raw_post: "{}", headers: {})

    assert_raises(PolarApi::Webhook::VerificationError) do
      PolarApi::Webhook.verify(request)
    end
  end

  private

  def verify_payload(secret:, key: nil, signature: nil)
    Polar.configure { |c| c.webhook_secret = secret }
    payload = { type: "order.paid", data: { id: "ord_1" }, api_version: "2026-04" }
    body = JSON.generate(payload)
    timestamp = Time.now.to_i.to_s
    msg_id = "msg_test"

    signature ||= begin
      digest = OpenSSL::HMAC.digest("SHA256", key, "#{msg_id}.#{timestamp}.#{body}")
      "v1,#{Base64.strict_encode64(digest)}"
    end

    request = OpenStruct.new(
      raw_post: body,
      headers: {
        "webhook-id" => msg_id,
        "webhook-timestamp" => timestamp,
        "webhook-signature" => signature,
        "webhook-api-version" => "2026-04"
      }
    )

    PolarApi::Webhook.verify(request)
  end
end
