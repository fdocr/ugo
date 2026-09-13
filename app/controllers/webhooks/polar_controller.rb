module Webhooks
  class PolarController < ActionController::Base
    skip_forgery_protection

    def receive
      event = PolarApi::Webhook.verify(request)
      Rails.logger.info("Polar webhook #{event.type} api_version=#{event.api_version}")

      case event.type
      when "subscription.active"
        handle_subscription_active(event.object)
      when "subscription.updated"
        handle_subscription_updated(event.object)
      when "subscription.past_due"
        handle_subscription_past_due(event.object)
      when "subscription.canceled", "subscription.revoked"
        handle_subscription_canceled(event.object)
      when "order.paid"
        handle_order_paid(event.object)
      end

      head :ok
    rescue PolarApi::Webhook::VerificationError => e
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
        workspace_id = hash_value(sub.metadata, :workspace_id)
        workspace = Workspace.find_by(id: workspace_id)
        return unless workspace

        product_id = sub.product_id.presence || hash_value(sub.product, :id)
        customer_id = sub.customer_id.presence || hash_value(sub.customer, :id)
        customer_email = hash_value(sub.customer, :email)

        subscription = workspace.build_subscription(
          status: :active,
          polar_subscription_id: sub.id,
          polar_customer_id: customer_id,
          polar_product_id: product_id,
          customer_email: customer_email,
          current_period_start: parse_time(sub.current_period_start),
          current_period_end: parse_time(sub.current_period_end),
          amount_cents: subscription_amount_cents(sub),
          currency: subscription_currency(sub)
        )
        subscription.save!
        workspace.update!(plan: plan_for_product(product_id), trial_ends_at: nil)
      end
    end

    def handle_subscription_updated(sub)
      subscription = Subscription.find_by(polar_subscription_id: sub.id)
      return unless subscription

      handle_subscription_past_due(sub)

      product_id = sub.product_id.presence || hash_value(sub.product, :id)
      if product_id.present? && product_id != subscription.polar_product_id
        subscription.update!(
          polar_product_id: product_id,
          amount_cents: subscription_amount_cents(sub, fallback: subscription.amount_cents)
        )
        subscription.workspace.update!(plan: plan_for_product(product_id))
      end
    end

    def handle_subscription_past_due(sub)
      subscription = Subscription.find_by(polar_subscription_id: sub.id)
      return unless subscription
      return unless sub.status == "past_due" && !subscription.past_due?

      subscription.update!(status: :past_due)
      BillingMailer.payment_failed(subscription).deliver_later
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

      subscription_id = order.subscription_id.presence || hash_value(order.subscription, :id)
      return unless subscription_id

      subscription = Subscription.find_by(polar_subscription_id: subscription_id)
      return unless subscription

      subscription.payments.create!(
        amount_cents: order_amount_cents(order, fallback: subscription.amount_cents),
        currency: (order.currency.presence || subscription.currency).upcase,
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

    def subscription_amount_cents(sub, fallback: 900)
      return sub.amount if sub.amount.present?

      price = first_price(sub.prices) || first_price(hash_value(sub.product, :prices))
      hash_value(price, :price_amount) || fallback
    end

    def subscription_currency(sub)
      value = sub.currency.presence || hash_value(first_price(sub.prices) || first_price(hash_value(sub.product, :prices)), :price_currency)
      (value.presence || "usd").upcase
    end

    def order_amount_cents(order, fallback:)
      order.net_amount.presence || order.total_amount.presence || order.amount.presence || fallback
    end

    def first_price(prices)
      Array(prices).first
    end

    def hash_value(object, key)
      return if object.nil?
      return object[key] || object[key.to_s] || object[key.to_sym] if object.is_a?(Hash)

      object.public_send(key) if object.respond_to?(key)
    end
  end
end
