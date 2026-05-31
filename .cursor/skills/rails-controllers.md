# Rails Controllers

## Base Controller

All controllers inherit from `ApplicationController`:

```ruby
class ApplicationController < ActionController::Base
  include Authentication

  private

  def current_user
    Current.user if authenticated?
  end

  def authenticate_admin!
    redirect_to "/", alert: "Not authorized" unless current_user&.site_admin?
  end

  def redirect_if_authenticated
    redirect_to root_path, notice: "Already signed in" if authenticated?
  end
end
```

## Controller Structure

### Standard Resourceful Controller

```ruby
class LinksController < ApplicationController
  before_action :set_workspace
  before_action :set_link, only: [:show, :edit, :update, :destroy]

  def index
    @links = @workspace.links
  end

  def show
  end

  def create
    @link = @workspace.links.create!(link_params)
    redirect_to workspace_link_path(@workspace.slug, @link.slug)
  end

  def edit
  end

  def update
    @link.update!(link_params)
    redirect_to workspace_link_path(@workspace.slug, @link.slug)
  end

  def destroy
    @link.destroy
    redirect_to workspace_path(@workspace.slug)
  end

  private

  def set_workspace
    @workspace = Current.user.workspaces.find_by!(slug: params[:workspace_id])
  end

  def set_link
    @link = @workspace.links.find_by!(slug: params[:id])
  end

  def link_params
    params.require(:link).permit(:name, :url, :slug)
  end
end
```

### Public Controller

```ruby
class HomeController < ApplicationController
  allow_unauthenticated_access only: [:index, :about, :privacy]

  def index
    redirect_to dashboard_path if authenticated?
  end

  def dashboard
    # Requires authentication (default)
  end
end
```

## Routing Patterns

### Resourceful Routes

```ruby
# config/routes.rb
resources :workspace, only: [:show, :update, :edit] do
  resources :links, except: [:new] do
    get "visits" => "visits#index"
  end
end
```

### Singular Resource

```ruby
resource :session  # No :id in routes
```

### Custom Routes

```ruby
get "sign_up" => "registrations#new"
post "sign_up" => "registrations#create"
delete "sign_up" => "registrations#destroy"

get "/:id" => "links#link", as: :link_redirect  # Catch-all for short URLs
```

### Namespaced API

```ruby
namespace :api do
  resources :links, only: [:show]
end
```

API controllers inherit from a base:

```ruby
# app/controllers/api/application_controller.rb
class Api::ApplicationController < ActionController::Base
  skip_before_action :verify_authenticity_token
  before_action :authenticate_api!

  private

  def authenticate_api!
    # Token-based auth for API
  end
end
```

## Before Actions

### Common Patterns

```ruby
class WorkspaceController < ApplicationController
  before_action :set_workspace
  before_action :authorize_workspace!, only: [:edit, :update]

  private

  def set_workspace
    @workspace = Current.user.workspaces.find_by!(slug: params[:id])
  end

  def authorize_workspace!
    # Additional authorization logic
  end
end
```

### Skip Authentication

```ruby
class LinksController < ApplicationController
  allow_unauthenticated_access only: [:link]  # Public short URL redirect
  
  def link
    @link = Link.find_by!(slug: params[:id])
    redirect_to @link.url, allow_other_host: true
  end
end
```

## Strong Parameters

```ruby
def link_params
  params.require(:link).permit(:name, :url, :slug, :description)
end

# Nested attributes
def workspace_params
  params.require(:workspace).permit(:name, :slug, links_attributes: [:id, :name, :url])
end
```

## Response Formats

### HTML (Default)

```ruby
def create
  @link = @workspace.links.create!(link_params)
  redirect_to workspace_link_path(@workspace.slug, @link.slug), notice: "Link created"
end
```

### Turbo Stream

```ruby
def create
  @link = @workspace.links.create!(link_params)
  
  respond_to do |format|
    format.html { redirect_to workspace_link_path(@workspace.slug, @link.slug) }
    format.turbo_stream
  end
end
```

### JSON (API)

```ruby
# app/controllers/api/links_controller.rb
def show
  @link = Link.find_by!(slug: params[:id])
  render json: @link
end
```

## Error Handling

```ruby
class ApplicationController < ActionController::Base
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  private

  def not_found
    render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
  end
end
```

## Invisible Captcha (Spam Protection)

```ruby
class RegistrationsController < ApplicationController
  invisible_captcha only: [:create], on_spam: :captcha_failure

  def create
    # Only reached if captcha passes
  end
end

# In ApplicationController
def captcha_failure
  Rails.logger.warn "Captcha failure (#{request.remote_ip})"
  head :no_content
end
```

## Key Conventions

- Always scope queries to `Current.user` for authorization
- Use `find_by!` to raise 404 on missing records
- Use strong parameters for mass assignment protection
- Prefer `redirect_to` with flash messages for HTML responses
- Use `allow_unauthenticated_access` for public endpoints
- Keep controllers thin - move business logic to models
