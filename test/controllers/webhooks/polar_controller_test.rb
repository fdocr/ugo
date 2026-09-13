require "test_helper"

class Webhooks::PolarControllerTest < ActionDispatch::IntegrationTest
  setup do
    setup_app_config_as_main_app!
    AppConfig.shared.update!(
      polar_basic_product_id: "prod_basic",
      polar_growth_product_id: "prod_growth"
    )
    @secret = "polar-hmac-secret"
    Polar.configure { |c| c.webhook_secret = @secret }
    @owner = users(:one)
    @workspace = Workspace.create!(name: "Polar WS", user: @owner, plan: :free)
  end

  test "rejects an unsigned payload" do
    post "/webhooks/polar",
      params: { type: "order.paid" }.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :unauthorized
  end

  test "subscription.active creates a subscription from top-level Polar fields" do
    payload = subscription_event(
      "subscription.active",
      id: "sub_new",
      product_id: "prod_growth",
      customer_id: "cus_1",
      amount: 1900,
      currency: "usd",
      customer: { id: "cus_ignored", email: "buyer@example.com" }
    )

    assert_difference "Subscription.count", 1 do
      post_polar_webhook(payload)
    end

    assert_response :ok
    subscription = @workspace.reload.subscription
    assert_equal "sub_new", subscription.polar_subscription_id
    assert_equal "cus_1", subscription.polar_customer_id
    assert_equal "prod_growth", subscription.polar_product_id
    assert_equal 1900, subscription.amount_cents
    assert_equal "USD", subscription.currency
    assert_equal "buyer@example.com", subscription.customer_email
    assert subscription.active?
    assert_equal "growth", @workspace.plan
    assert_nil @workspace.trial_ends_at
  end

  test "subscription.active falls back to nested customer and product prices" do
    payload = subscription_event(
      "subscription.active",
      id: "sub_nested",
      product_id: nil,
      customer_id: nil,
      amount: nil,
      currency: nil,
      customer: { id: "cus_nested", email: "nested@example.com" },
      product: {
        id: "prod_basic",
        prices: [ { price_amount: 900, price_currency: "usd" } ]
      }
    )

    post_polar_webhook(payload)
    assert_response :ok

    subscription = @workspace.reload.subscription
    assert_equal "cus_nested", subscription.polar_customer_id
    assert_equal "prod_basic", subscription.polar_product_id
    assert_equal 900, subscription.amount_cents
    assert_equal "basic", @workspace.plan
  end

  test "subscription.updated marks past_due and enqueues a payment failed email" do
    subscription = create_subscription!

    assert_enqueued_emails 1 do
      post_polar_webhook(subscription_event("subscription.updated", id: subscription.polar_subscription_id, status: "past_due"))
    end

    assert_response :ok
    assert subscription.reload.past_due?
  end

  test "subscription.past_due is idempotent after subscription.updated" do
    subscription = create_subscription!

    post_polar_webhook(subscription_event("subscription.updated", id: subscription.polar_subscription_id, status: "past_due"))
    assert_enqueued_emails 0 do
      post_polar_webhook(subscription_event("subscription.past_due", id: subscription.polar_subscription_id, status: "past_due"))
    end

    assert subscription.reload.past_due?
  end

  test "subscription.updated upgrades the plan when the product changes" do
    subscription = create_subscription!(polar_product_id: "prod_basic", amount_cents: 900)
    @workspace.update!(plan: :basic)

    post_polar_webhook(
      subscription_event(
        "subscription.updated",
        id: subscription.polar_subscription_id,
        product_id: "prod_growth",
        amount: 1900
      )
    )

    assert_response :ok
    assert_equal "prod_growth", subscription.reload.polar_product_id
    assert_equal 1900, subscription.amount_cents
    assert_equal "growth", @workspace.reload.plan
  end

  test "subscription.canceled with cancel_at_period_end keeps access" do
    subscription = create_subscription!
    @workspace.update!(plan: :basic)

    post_polar_webhook(
      subscription_event("subscription.canceled", id: subscription.polar_subscription_id, cancel_at_period_end: true)
    )

    assert subscription.reload.active?
    assert_not_nil subscription.cancelled_at
    assert_equal "basic", @workspace.reload.plan
  end

  test "subscription.revoked immediately downgrades the workspace" do
    subscription = create_subscription!
    @workspace.update!(plan: :basic)

    post_polar_webhook(
      subscription_event("subscription.revoked", id: subscription.polar_subscription_id, cancel_at_period_end: false, status: "canceled")
    )

    assert subscription.reload.cancelled?
    assert_equal "free", @workspace.reload.plan
  end

  test "order.paid records net_amount from the Polar order" do
    subscription = create_subscription!(amount_cents: 900)

    payload = {
      type: "order.paid",
      data: {
        id: "ord_1",
        net_amount: 972,
        total_amount: 972,
        amount: 900,
        currency: "usd",
        subscription_id: subscription.polar_subscription_id,
        created_at: Time.current.iso8601
      },
      api_version: "2026-04"
    }

    assert_difference "Payment.count", 1 do
      post_polar_webhook(payload)
    end

    payment = subscription.payments.last
    assert_equal 972, payment.amount_cents
    assert_equal "USD", payment.currency
    assert_equal "ord_1", payment.polar_order_id
    assert payment.succeeded?
  end

  test "order.paid falls back to nested subscription id and amount alias" do
    subscription = create_subscription!(amount_cents: 900)

    payload = {
      type: "order.paid",
      data: {
        id: "ord_legacy",
        amount: 900,
        currency: "usd",
        subscription: { id: subscription.polar_subscription_id },
        created_at: Time.current.iso8601
      }
    }

    post_polar_webhook(payload)
    assert_equal 900, subscription.payments.last.amount_cents
  end

  test "order.paid is idempotent for the same polar_order_id" do
    subscription = create_subscription!

    payload = {
      type: "order.paid",
      data: {
        id: "ord_dup",
        net_amount: 900,
        currency: "usd",
        subscription_id: subscription.polar_subscription_id,
        created_at: Time.current.iso8601
      }
    }

    post_polar_webhook(payload)
    assert_no_difference "Payment.count" do
      post_polar_webhook(payload)
    end
  end

  private

  def create_subscription!(**attrs)
    @workspace.create_subscription!({
      status: :active,
      polar_subscription_id: "sub_existing",
      polar_customer_id: "cus_existing",
      polar_product_id: "prod_basic",
      amount_cents: 900,
      currency: "USD",
      customer_email: @owner.email
    }.merge(attrs))
  end

  def subscription_event(type, id:, **attrs)
    {
      type: type,
      data: {
        id: id,
        status: "active",
        cancel_at_period_end: false,
        current_period_start: 1.day.ago.iso8601,
        current_period_end: 1.month.from_now.iso8601,
        metadata: { workspace_id: @workspace.id.to_s }
      }.merge(attrs).compact,
      api_version: "2026-04"
    }
  end

  def post_polar_webhook(payload)
    body = JSON.generate(payload.deep_stringify_keys)
    timestamp = Time.now.to_i.to_s
    msg_id = "msg_#{SecureRandom.hex(4)}"
    digest = OpenSSL::HMAC.digest("SHA256", @secret.encode("UTF-8"), "#{msg_id}.#{timestamp}.#{body}")

    post "/webhooks/polar",
      params: body,
      headers: {
        "Content-Type" => "application/json",
        "Webhook-Id" => msg_id,
        "Webhook-Timestamp" => timestamp,
        "Webhook-Signature" => "v1,#{Base64.strict_encode64(digest)}",
        "Webhook-Api-Version" => "2026-04"
      }
  end
end
