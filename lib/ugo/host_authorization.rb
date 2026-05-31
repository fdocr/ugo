# frozen_string_literal: true

module Ugo
  module HostAuthorization
    module_function

    def allowed_host?(host)
      cfg = AppConfig.shared
      return true unless cfg.setup_completed?

      domain = cfg.app_domain.presence
      return false if domain.blank?

      host == domain || host == "www.#{domain}"
    end
  end
end
