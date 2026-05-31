# Rails 8 Authentication

This project uses vanilla Rails 8 authentication with `has_secure_password` - no Devise or other gems.

## Core Components

### User Model

`app/models/user.rb` uses bcrypt for password hashing:

```ruby
class User < ApplicationRecord
  has_secure_password

  validates :email, presence: true, uniqueness: true
  normalizes :email, with: ->(e) { e.strip.downcase }
end
```

### Authentication Concern

Located at `app/controllers/concerns/authentication.rb`, included in `ApplicationController`:

```ruby
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end
end
```

### Current Model

`app/models/current.rb` provides request-scoped state via `ActiveSupport::CurrentAttributes`:

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :session
  delegate :user, to: :session, allow_nil: true
end
```

Access the current user anywhere with `Current.user`.

### Session Model

`app/models/session.rb` stores authentication sessions:
- Belongs to User
- Tracks `user_agent` and `ip_address`
- Session ID stored in signed cookie

## Authentication Patterns

### Require Authentication (Default)

All controllers require authentication by default. No action needed:

```ruby
class LinksController < ApplicationController
  # All actions require authentication automatically
end
```

### Allow Unauthenticated Access

Use `allow_unauthenticated_access` to skip authentication:

```ruby
class HomeController < ApplicationController
  allow_unauthenticated_access only: [:index, :about, :privacy]
end
```

### Check Authentication in Views

```erb
<% if authenticated? %>
  <%= link_to "Dashboard", dashboard_path %>
<% else %>
  <%= link_to "Sign In", new_session_path %>
<% end %>
```

### Access Current User

```ruby
# In controllers
Current.user
current_user  # helper method defined in ApplicationController

# In views
Current.user.email
```

## Authentication Flows

### Sign Up (Registration)

1. User enters email and password at `/sign_up`
2. User created with `has_secure_password`
3. Workspace auto-generated from email prefix
4. User signed in immediately and redirected to dashboard

```ruby
# RegistrationsController#create
@user = User.new(email: params[:email], password: params[:password], password_confirmation: params[:password_confirmation])
@user.save!
workspace_slug = @user.email.split("@").first.parameterize
Workspace.create!(user: @user, slug: workspace_slug)
start_new_session_for(@user)
redirect_to dashboard_path
```

### Sign In (Password Authentication)

1. User enters email and password at `/session/new`
2. `User#authenticate` validates password
3. Session created and stored in signed cookie

```ruby
# SessionsController#create
user = User.find_by(email: params[:email])
if user&.authenticate(params[:password])
  start_new_session_for(user)
  redirect_to dashboard_path
else
  redirect_to new_session_path, alert: "Invalid email or password"
end
```

### Session Management

```ruby
# Start session (in Authentication concern)
def start_new_session_for(user)
  user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
    Current.session = session
    cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
  end
end

# End session
def terminate_session
  Current.session.destroy
  cookies.delete(:session_id)
end
```

## Routes

```ruby
resource :session                           # login/logout
resources :passwords, param: :token         # password reset
get "sign_up" => "registrations#new"        # registration
post "sign_up" => "registrations#create"
delete "sign_up" => "registrations#destroy"
```

## Site Admin Authorization

Site-wide admin access is stored as a boolean column on the users table:

```ruby
# Migration
add_column :users, :site_admin, :boolean, default: false, null: false

# User model - Rails auto-generates site_admin? from the boolean column
# Alias for backward compatibility
alias_method :admin?, :site_admin?

# In ApplicationController
def authenticate_site_admin!
  redirect_to "/", alert: "Not authorized" unless Current.user&.site_admin?
end

# In admin controllers
class AdminController < ApplicationController
  before_action :authenticate_site_admin!
end

# Grant site admin access
user.update!(site_admin: true)
```

## Workspace Authorization

Workspace access is controlled through memberships with roles. This uses a plain Ruby pattern (no Pundit/CanCanCan).

### Membership Model

```ruby
class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :workspace

  enum :role, { member: 0, admin: 1 }

  validates :user_id, uniqueness: { scope: :workspace_id }
  validates :role, presence: true
end
```

### Workspace Authorization Methods

```ruby
# In Workspace model
def member?(user)
  return false unless user
  memberships.exists?(user: user)
end

def admin?(user)
  return false unless user
  memberships.exists?(user: user, role: :admin)
end

def membership_for(user)
  memberships.find_by(user: user)
end

def role_for(user)
  membership_for(user)&.role
end
```

### WorkspaceAuthorization Concern

Located at `app/controllers/concerns/workspace_authorization.rb`:

```ruby
module WorkspaceAuthorization
  extend ActiveSupport::Concern

  included do
    helper_method :current_membership, :workspace_admin?
  end

  private

  def current_membership
    @current_membership ||= @workspace&.membership_for(Current.user)
  end

  def workspace_admin?
    @workspace&.admin?(Current.user)
  end

  def authorize_workspace_member!
    return if @workspace&.member?(Current.user)
    handle_unauthorized("You don't have access to this workspace")
  end

  def authorize_workspace_admin!
    return if @workspace&.admin?(Current.user)
    handle_unauthorized("You need admin access to perform this action")
  end

  def handle_unauthorized(message)
    respond_to do |format|
      format.html { redirect_to dashboard_path, alert: message }
      format.json { render json: { error: message }, status: :forbidden }
    end
  end
end
```

### Using in Controllers

```ruby
class LinksController < ApplicationController
  include WorkspaceAuthorization

  before_action :set_workspace
  before_action :authorize_workspace_member!

  # All actions now require workspace membership
end

class WorkspaceController < ApplicationController
  include WorkspaceAuthorization

  before_action :set_workspace
  before_action :authorize_workspace_member!
  before_action :authorize_workspace_admin!, only: [:edit, :update]

  # edit/update require admin role
end
```

### Checking Roles in Views

```erb
<% if workspace_admin? %>
  <%= link_to "Settings", edit_workspace_path(@workspace) %>
<% end %>

<% if current_membership&.admin? %>
  <%= render "admin_controls" %>
<% end %>
```

## Testing Authorization

**Every controller with authorization MUST have tests for:**

1. Unauthenticated users redirected to login
2. Non-members cannot access resources
3. Members can access but not perform admin actions
4. Admins can perform privileged actions

### Example Authorization Tests

```ruby
class InvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = users(:one)
    @member_user = users(:two)
    @workspace = workspaces(:one)
  end

  # 1. Authentication required
  test "should redirect to login when not authenticated" do
    post workspace_invitations_path(@workspace), params: { invitation: { email: "new@example.com" } }
    assert_redirected_to new_session_path
  end

  # 2. Non-members denied
  test "non-member cannot create invitation" do
    other_user = User.create!(email: "other@example.com", password: "password123")
    sign_in other_user

    assert_no_difference "Invitation.count" do
      post workspace_invitations_path(@workspace), params: { invitation: { email: "new@example.com" } }
    end

    assert_redirected_to dashboard_path
  end

  # 3. Members cannot perform admin actions
  test "member cannot create invitation" do
    sign_in @member_user

    assert_no_difference "Invitation.count" do
      post workspace_invitations_path(@workspace), params: { invitation: { email: "new@example.com" } }
    end

    assert_redirected_to dashboard_path
    assert_equal "You need admin access to perform this action", flash[:alert]
  end

  # 4. Admins can perform privileged actions
  test "admin can create invitation" do
    sign_in @admin_user

    assert_difference "Invitation.count", 1 do
      post workspace_invitations_path(@workspace), params: { invitation: { email: "new@example.com" } }
    end
  end

  private

  def sign_in(user)
    post session_path, params: { email: user.email, password: "password123" }
  end
end
```

### Membership Fixtures

```yaml
# test/fixtures/memberships.yml
one_admin:
  user: one
  workspace: one
  role: 1  # admin

two_member_of_one:
  user: two
  workspace: one
  role: 0  # member
```

## Key Conventions

### Authentication
- Use `has_secure_password` for password hashing (bcrypt)
- Use `Current.user` for current user access
- Use `allow_unauthenticated_access` for public pages
- Use `authenticated?` helper in views
- Sessions are database-backed, not cookie-based
- Signed cookies store only the session ID
- Workspace is auto-generated on registration from email prefix

### Authorization
- Use plain Ruby pattern (no Pundit/CanCanCan)
- Site admin access via `site_admin` boolean column on users table
- Workspace roles: `admin` and `member` only
- Include `WorkspaceAuthorization` concern in workspace-scoped controllers
- Use `authorize_workspace_member!` for general access
- Use `authorize_workspace_admin!` for privileged actions
- Use `workspace_admin?` helper in views for conditional UI
- **Always test all 4 authorization scenarios**: unauthenticated, non-member, member, admin
