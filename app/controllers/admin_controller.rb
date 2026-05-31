class AdminController < ApplicationController
  before_action :authenticate_site_admin!
end
