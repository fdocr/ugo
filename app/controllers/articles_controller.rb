class ArticlesController < ApplicationController
  allow_unauthenticated_access only: :open_beta

  before_action :redirect_self_hosted_to_root

  def open_beta
    @page_title = "Open Beta"
    @back_url = root_path
  end

  private

  def redirect_self_hosted_to_root
    redirect_to root_path if self_hosted?
  end
end
