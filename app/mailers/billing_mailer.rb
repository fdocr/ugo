class BillingMailer < ApplicationMailer
  def payment_failed(subscription)
    @subscription = subscription
    @workspace = subscription.workspace
    @app_name = AppConfig.shared.app_name
    host = AppConfig.shared.app_domain.presence || "localhost"
    @billing_url = workspace_billing_url(@workspace, host: host)
    @manage_url = manage_workspace_billing_url(@workspace, host: host)

    mail(
      to: @subscription.customer_email,
      subject: "#{@app_name} — Payment failed for #{@workspace.name}"
    )
  end
end
