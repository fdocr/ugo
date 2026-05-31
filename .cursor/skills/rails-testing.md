# Rails Testing

This project uses Minitest (Rails default) - not RSpec.

## Running Tests

```bash
# Run all tests
bin/rails test

# Run specific file
bin/rails test test/models/user_test.rb

# Run specific test by line number
bin/rails test test/models/user_test.rb:10

# Run with verbose output
bin/rails test -v

# Run system tests
bin/rails test:system
```

## Test Structure

```
test/
  controllers/
    links_controller_test.rb
    api/
      links_controller_test.rb
  models/
    user_test.rb
    link_test.rb
  jobs/
    process_visits_job_test.rb
  mailers/
    passwords_mailer_test.rb
  helpers/
    workspace_helper_test.rb
  integration/
  system/
  fixtures/
    users.yml
    links.yml
    workspaces.yml
  test_helper.rb
```

## Test Helper

```ruby
# test/test_helper.rb
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all
  end
end
```

## Fixtures

### Basic Fixtures

```yaml
# test/fixtures/users.yml
one:
  email: one@example.com

two:
  email: two@example.com

admin:
  email: admin@example.com
  role: admin
```

### Fixtures with Associations

```yaml
# test/fixtures/workspaces.yml
one:
  user: one
  name: Workspace One
  slug: workspace-one

# test/fixtures/links.yml
one:
  workspace: one
  name: Link One
  slug: abc123
  url: https://example.com
```

### Accessing Fixtures

```ruby
class UserTest < ActiveSupport::TestCase
  test "fixture is loaded" do
    user = users(:one)
    assert_equal "one@example.com", user.email
  end
end
```

## Model Tests

```ruby
# test/models/user_test.rb
require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "email is normalized" do
    user = User.new(email: "  FOO@BAR.COM  ")
    assert_equal "foo@bar.com", user.email
  end

  test "email must be present" do
    user = User.new(email: nil)
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "email must be unique" do
    existing = users(:one)
    user = User.new(email: existing.email)
    assert_not user.valid?
  end

  test "authenticate with correct password" do
    user = users(:one)
    assert user.authenticate("password123")
  end

  test "reject incorrect password" do
    user = users(:one)
    assert_not user.authenticate("wrong")
  end
end
```

## Controller Tests (Integration)

```ruby
# test/controllers/home_controller_test.rb
require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_url
    assert_response :success
  end

  test "dashboard requires authentication" do
    get dashboard_url
    assert_redirected_to new_session_url
  end

  test "dashboard accessible when authenticated" do
    sign_in users(:one)
    get dashboard_url
    assert_response :success
  end
end
```

### Authentication Helper

```ruby
# test/test_helper.rb
class ActionDispatch::IntegrationTest
  def sign_in(user)
    session = user.sessions.create!(
      user_agent: "Test Agent",
      ip_address: "127.0.0.1"
    )
    cookies[:session_id] = session.id
  end

  def sign_out
    cookies.delete(:session_id)
  end
end
```

### Testing with Parameters

```ruby
test "create link" do
  sign_in users(:one)
  workspace = workspaces(:one)

  assert_difference "Link.count", 1 do
    post workspace_links_url(workspace.slug), params: {
      link: { name: "New Link", url: "https://example.com" }
    }
  end

  assert_redirected_to workspace_link_url(workspace.slug, Link.last.slug)
end
```

## Job Tests

```ruby
# test/jobs/process_visits_job_test.rb
require "test_helper"

class ProcessVisitsJobTest < ActiveJob::TestCase
  test "processes unprocessed visits" do
    visit = visits(:unprocessed)
    
    ProcessVisitsJob.perform_now
    
    visit.reload
    assert_not_nil visit.processed_at
  end

  test "job is enqueued" do
    assert_enqueued_with(job: ProcessVisitsJob) do
      ProcessVisitsJob.perform_later
    end
  end
end
```

## Mailer Tests

```ruby
# test/mailers/passwords_mailer_test.rb
require "test_helper"

class PasswordsMailerTest < ActionMailer::TestCase
  test "reset email" do
    user = users(:one)

    email = PasswordsMailer.with(user: user, token: "abc123").reset

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal ["one@example.com"], email.to
    assert_equal "Your login link", email.subject
    assert_match "abc123", email.body.encoded
  end
end
```

## Helper Tests

```ruby
# test/helpers/workspace_helper_test.rb
require "test_helper"

class WorkspaceHelperTest < ActionView::TestCase
  test "plan_badge returns correct class" do
    workspace = workspaces(:one)
    result = plan_badge(workspace)
    
    assert_includes result, "badge"
  end
end
```

## Assertions

### Common Assertions

```ruby
assert true                           # Basic truth
assert_equal expected, actual         # Equality
assert_not_equal a, b                 # Inequality
assert_nil value                      # Nil check
assert_not_nil value                  # Not nil
assert_includes collection, item      # Contains
assert_match /pattern/, string        # Regex match
assert_raises(Error) { code }         # Exception
```

### Rails-Specific Assertions

```ruby
assert_response :success              # HTTP 200
assert_response :redirect             # HTTP 3xx
assert_redirected_to path             # Redirect location
assert_difference "Model.count", 1    # Count change
assert_no_difference "Model.count"    # No count change
assert_emails 1                       # Email sent count
assert_enqueued_with(job: MyJob)      # Job enqueued
```

## System Tests (Browser)

```ruby
# test/system/links_test.rb
require "application_system_test_case"

class LinksTest < ApplicationSystemTestCase
  test "creating a link" do
    sign_in users(:one)
    visit workspace_url(workspaces(:one).slug)

    click_on "Create link"
    fill_in "Name", with: "My Link"
    fill_in "URL", with: "https://example.com"
    click_on "Save"

    assert_text "Link created"
  end
end
```

## Test Data with Faker

```ruby
# test/models/user_test.rb
require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "create user with faker" do
    user = User.create!(
      email: Faker::Internet.email
    )
    assert user.persisted?
  end
end
```

## Key Conventions

- Use Minitest, not RSpec
- Use fixtures for test data
- Use integration tests for controllers
- Test authentication with helper methods
- Use `assert_difference` for count changes
- Use `assert_enqueued_with` for jobs
- Keep tests fast - avoid unnecessary setup
- One assertion per test when possible
