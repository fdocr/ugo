module Dev
  class StyleguideController < ApplicationController
    layout "application"
    skip_before_action :redirect_to_setup_if_needed

    before_action :ensure_development!

    def show
    end

    private

    def ensure_development!
      head :not_found unless Rails.env.development?
    end
  end
end
