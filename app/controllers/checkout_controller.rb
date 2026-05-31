class CheckoutController < ApplicationController
  VALID_PLANS = %w[basic growth].freeze

  before_action :load_workspace
  before_action :authorize_workspace_admin!
  before_action :redirect_if_self_hosted
  before_action :redirect_if_already_subscribed
  before_action :load_plan, only: :new

  def new
    product_id = AppConfig.polar_product_id(@plan)

    checkout = Polar::Checkout::Custom.create(
      product_id: product_id,
      success_url: workspace_checkout_url(@workspace),
      customer_email: Current.user.email,
      metadata: { workspace_id: @workspace.id.to_s }
    )

    redirect_to checkout.url, allow_other_host: true
  rescue Polar::Error => e
    Rails.logger.error "Polar checkout creation failed: #{e.message}"
    redirect_to workspace_billing_path(@workspace), alert: "Payment system is temporarily unavailable. Please try again later."
  end

  def show
    @page_title = "Payment Processing"
    @back_url = workspace_path(@workspace)
  end

  private

  def load_workspace
    @workspace = Current.user.workspaces.find_by(id: params[:workspace_id])
    redirect_to dashboard_path, alert: "Workspace not found" if @workspace.nil?
  end

  def load_plan
    @plan = params[:plan].to_s.presence || "basic"
    unless VALID_PLANS.include?(@plan)
      redirect_to workspace_billing_path(@workspace), alert: "Invalid plan selected."
    end
  end

  def redirect_if_self_hosted
    redirect_to workspace_path(@workspace) if AppConfig.self_hosted?
  end

  def redirect_if_already_subscribed
    return unless @workspace.subscription&.active?
    redirect_to workspace_billing_path(@workspace), notice: "You already have an active subscription."
  end
end
