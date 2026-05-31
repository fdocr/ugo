class BillingController < ApplicationController
  before_action :load_workspace
  before_action :authorize_workspace_admin!
  before_action :redirect_if_self_hosted

  def show
    @subscription = @workspace.subscription
    @payments = @subscription&.payments&.recent || Payment.none

    setup_navbar
  end

  def manage
    subscription = @workspace.subscription

    unless subscription&.polar_customer_id.present?
      redirect_to workspace_billing_path(@workspace), alert: "No billing account found."
      return
    end

    session = Polar::CustomerSession.create(
      customer_id: subscription.polar_customer_id,
      return_url: workspace_billing_url(@workspace)
    )

    redirect_to session.customer_portal_url, allow_other_host: true
  rescue Polar::Error => e
    Rails.logger.error "Polar customer session failed: #{e.message}"
    redirect_to workspace_billing_path(@workspace), alert: "Unable to open billing portal. Please try again later."
  end

  def cancel
    subscription = @workspace.subscription

    unless subscription&.active?
      redirect_to workspace_billing_path(@workspace), alert: "No active subscription to cancel."
      return
    end

    if subscription.polar_subscription_id.present?
      Polar::Client.delete_request("/v1/subscriptions/#{subscription.polar_subscription_id}")
    end

    subscription.update!(status: :cancelled, cancelled_at: Time.current)
    @workspace.update!(plan: :free)

    redirect_to workspace_billing_path(@workspace), notice: "Your subscription has been cancelled."
  rescue Polar::Error => e
    Rails.logger.error "Polar cancellation failed: #{e.message}"
    redirect_to workspace_billing_path(@workspace), alert: "Unable to cancel subscription. Please try again or contact support."
  end

  private

  def load_workspace
    @workspace = Current.user.workspaces.find_by(id: params[:workspace_id])
    redirect_to dashboard_path, alert: "Workspace not found" if @workspace.nil?
  end

  def redirect_if_self_hosted
    redirect_to workspace_path(@workspace) if AppConfig.self_hosted?
  end

  def setup_navbar
    @page_title = "Billing"
    @back_url = workspace_path(@workspace)
  end
end
