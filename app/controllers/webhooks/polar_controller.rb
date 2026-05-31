module Webhooks
  class PolarController < ActionController::Base
    skip_forgery_protection

    def receive
      event = Polar::Webhook.verify(request)

      case event.type
      when "subscription.active"
        handle_subscription_active(event.object)
      when "subscription.updated"
        handle_subscription_updated(event.object)
      when "subscription.canceled", "subscription.revoked"
        handle_subscription_canceled(event.object)
      when "order.paid"
        handle_order_paid(event.object)
      end

      head :ok
    rescue StandardWebhooks::WebhookVerificationError => e
      Rails.logger.warn "Polar webhook verification failed: #{e.message}"
      head :unauthorized
    rescue JSON::ParserError
      head :bad_request
    end

    private

    def handle_subscription_active(sub)
      subscription = Subscription.find_by(polar_subscription_id: sub.id)

      if subscription
        subscription.update!(
          status: :active,
          current_period_start: parse_time(sub.current_period_start),
          current_period_end: parse_time(sub.current_period_end)
        )
        subscription.workspace.update!(trial_ends_at: nil)
      else
        workspace_id = sub.metadata&.dig(:workspace_id)
        workspace = Workspace.find_by(id: workspace_id)
        return unless workspace

        customer = sub.customer || {}
        product = sub.product || {}
        price = product[:prices]&.first || {}
        amount = price[:price_amount] || 900

        subscription = workspace.build_subscription(
          status: :active,
          polar_subscription_id: sub.id,
          polar_customer_id: customer[:id],
          polar_product_id: product[:id],
          customer_email: customer[:email],
          current_period_start: parse_time(sub.current_period_start),
          current_period_end: parse_time(sub.current_period_end),
          amount_cents: amount,
          currency: (price[:price_currency] || "usd").upcase
        )
        subscription.save!
        workspace.update!(plan: plan_for_product(product[:id]), trial_ends_at: nil)
      end
    end

    def handle_subscription_updated(sub)
      subscription = Subscription.find_by(polar_subscription_id: sub.id)
      return unless subscription

      if sub.status == "past_due" && !subscription.past_due?
        subscription.update!(status: :past_due)
        BillingMailer.payment_failed(subscription).deliver_later
      end

      product = sub.product || {}
      new_product_id = product[:id]
      if new_product_id.present? && new_product_id != subscription.polar_product_id
        new_plan = plan_for_product(new_product_id)
        price = product[:prices]&.first || {}
        subscription.update!(
          polar_product_id: new_product_id,
          amount_cents: price[:price_amount] || subscription.amount_cents
        )
        subscription.workspace.update!(plan: new_plan)
      end
    end

    def handle_subscription_canceled(sub)
      subscription = Subscription.find_by(polar_subscription_id: sub.id)
      return unless subscription

      if sub.cancel_at_period_end
        subscription.update!(cancelled_at: Time.current)
      else
        subscription.update!(status: :cancelled, cancelled_at: Time.current)
        subscription.workspace.update!(plan: :free)
      end
    end

    def handle_order_paid(order)
      return if Payment.exists?(polar_order_id: order.id)

      subscription_data = order.subscription
      return unless subscription_data

      subscription = Subscription.find_by(polar_subscription_id: subscription_data[:id])
      return unless subscription

      amount = order.amount || subscription.amount_cents
      currency = (order.currency || subscription.currency).upcase

      payment = subscription.payments.create!(
        amount_cents: amount,
        currency: currency,
        status: :succeeded,
        polar_order_id: order.id,
        paid_at: parse_time(order.created_at)
      )
    end

    def parse_time(value)
      return nil if value.blank?
      Time.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def plan_for_product(product_id)
      basic_id = AppConfig.polar_product_id(:basic)
      growth_id = AppConfig.polar_product_id(:growth)
      return :basic if product_id == basic_id
      return :growth if product_id == growth_id
      :basic
    end
  end
end
