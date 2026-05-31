# Rails Jobs & Mailers

## Background Jobs (Solid Queue)

This project uses Solid Queue with SQLite for background job processing.

### Configuration

```ruby
# config/environments/production.rb
config.active_job.queue_adapter = :solid_queue
config.solid_queue.connects_to = { database: { writing: :queue } }
```

### Running Workers

In development, Solid Queue runs automatically via Puma plugin:

```ruby
# config/puma.rb
plugin :solid_queue
```

Manual start:

```bash
bin/jobs
```

### Job Structure

```ruby
# app/jobs/process_visits_job.rb
class ProcessVisitsJob < ApplicationJob
  queue_as :default

  def perform(*args)
    # Job logic here
    Visit.unprocessed.find_each do |visit|
      process_visit(visit)
    end
  end

  private

  def process_visit(visit)
    # Processing logic
    visit.update!(processed_at: Time.current)
  end
end
```

### Enqueuing Jobs

```ruby
# Enqueue for immediate processing
ProcessVisitsJob.perform_later

# Enqueue with arguments
SendEmailJob.perform_later(user_id: 1, template: "welcome")

# Enqueue for later
CleanupJob.set(wait: 1.hour).perform_later
CleanupJob.set(wait_until: Date.tomorrow.noon).perform_later

# Enqueue on specific queue
ImportJob.set(queue: :low_priority).perform_later
```

### Job Options

```ruby
class ImportJob < ApplicationJob
  queue_as :imports
  
  # Retry configuration
  retry_on StandardError, wait: 5.seconds, attempts: 3
  
  # Discard on specific errors
  discard_on ActiveRecord::RecordNotFound

  def perform(file_path)
    # Import logic
  end
end
```

### Recurring Jobs

```yaml
# config/recurring.yml
production:
  process_visits:
    class: ProcessVisitsJob
    schedule: every 5 minutes
  
  cleanup:
    class: CleanupVisitsJob
    schedule: every day at 3am
    args: [30]  # days to keep
```

### Mission Control (Job Dashboard)

Access at `/jobs` in development and production:

```ruby
# config/routes.rb
mount MissionControl::Jobs::Engine, at: "/jobs"
```

## Mailers

### Mailer Structure

```ruby
# app/mailers/application_mailer.rb
class ApplicationMailer < ActionMailer::Base
  default from: "noreply@example.com"
  layout "mailer"
end

# app/mailers/passwords_mailer.rb
class PasswordsMailer < ApplicationMailer
  def reset
    @user = params[:user]
    @token = params[:token]
    @reset_url = edit_password_url(@token)

    mail(
      to: @user.email,
      subject: "Reset your password"
    )
  end
end
```

### Mailer Views

```
app/views/
  passwords_mailer/
    reset.html.erb
    reset.text.erb
  layouts/
    mailer.html.erb
    mailer.text.erb
```

```erb
<!-- app/views/passwords_mailer/reset.html.erb -->
<h1>Reset your password</h1>

<p>Click the link below to reset your password:</p>

<p><%= link_to "Reset Password", @reset_url %></p>

<p>This link expires in 1 hour.</p>
```

### Sending Emails

```ruby
# With params (preferred)
PasswordsMailer.with(user: @user, token: @token).reset.deliver_later

# With arguments
WelcomeMailer.welcome_email(@user).deliver_later

# Deliver immediately (avoid in web requests)
PasswordsMailer.with(user: @user, token: @token).reset.deliver_now
```

### Mailer Layouts

```erb
<!-- app/views/layouts/mailer.html.erb -->
<!DOCTYPE html>
<html>
  <head>
    <meta content="text/html; charset=UTF-8" http-equiv="Content-Type" />
    <style>
      body { font-family: sans-serif; }
    </style>
  </head>
  <body>
    <%= yield %>
    
    <hr>
    <p style="color: #666; font-size: 12px;">
      Sent from <%= Rails.application.class.module_parent_name %>
    </p>
  </body>
</html>
```

### Preview Mailers

```ruby
# test/mailers/previews/passwords_mailer_preview.rb
class PasswordsMailerPreview < ActionMailer::Preview
  def reset
    user = User.first
    PasswordsMailer.with(user: user, token: "preview-token").reset
  end
end
```

Access previews at: `http://localhost:3000/rails/mailers`

### Development: Letter Opener

Emails open in browser instead of sending:

```ruby
# Gemfile
gem "letter_opener", group: :development

# config/environments/development.rb
config.action_mailer.delivery_method = :letter_opener
```

### Production: SMTP

```ruby
# config/environments/production.rb
config.action_mailer.smtp_settings = {
  address: "smtp.example.com",
  port: 587,
  user_name: Rails.application.credentials.dig(:smtp, :user_name),
  password: Rails.application.credentials.dig(:smtp, :password),
  authentication: :plain,
  enable_starttls_auto: true
}
```

## Common Patterns

### Job That Sends Email

```ruby
class NotificationJob < ApplicationJob
  queue_as :default

  def perform(user_id, notification_type)
    user = User.find(user_id)
    
    case notification_type
    when "welcome"
      OnboardingMailer.with(user: user).welcome_email.deliver_now
    when "reminder"
      ReminderMailer.with(user: user).reminder_email.deliver_now
    end
  end
end
```

### Batch Processing Job

```ruby
class ProcessVisitsJob < ApplicationJob
  queue_as :default

  def perform
    visits = Visit.where(processed_at: nil)
                  .where("created_at < ?", Time.current)
                  .order(created_at: :desc)

    visits.find_each(batch_size: 50) do |visit|
      next if visit.processed_at.present?  # Guard against race conditions
      
      process_single_visit(visit)
    end
  end

  private

  def process_single_visit(visit)
    # Processing logic
    visit.update!(processed_at: Time.current)
  rescue StandardError => e
    Rails.logger.error "Failed to process visit #{visit.id}: #{e.message}"
  end
end
```

### Mailer with Attachments

```ruby
class ReportMailer < ApplicationMailer
  def monthly_report
    @user = params[:user]
    @report = params[:report]

    attachments["report.pdf"] = @report.to_pdf
    attachments.inline["logo.png"] = File.read("app/assets/images/logo.png")

    mail(to: @user.email, subject: "Your Monthly Report")
  end
end
```

## Key Conventions

- Use `deliver_later` for all emails (async via Solid Queue)
- Use `params[:key]` pattern for mailer data
- Always provide both HTML and text email templates
- Use `find_each` for processing large datasets in jobs
- Guard against race conditions in batch jobs
- Use recurring jobs for scheduled tasks
- Access job dashboard at `/jobs`
