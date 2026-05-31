# Rails Models

## Base Model

All models inherit from `ApplicationRecord`:

```ruby
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
```

## Model Structure

### Complete Example

```ruby
class User < ApplicationRecord
  # Password authentication
  has_secure_password

  # Enums
  enum :role, [ :user, :admin ]

  # Associations
  has_many :sessions, dependent: :destroy
  has_many :workspaces, dependent: :destroy
  has_many :links, through: :workspaces

  # Normalizations
  normalizes :email, with: ->(e) { e.strip.downcase }

  # Validations
  validates :email, presence: true, uniqueness: true

  # Instance methods
  def logged_in!
    self.last_login_at = Time.current
    save!
  end
end
```

## Associations

### Has Many

```ruby
class User < ApplicationRecord
  has_many :workspaces, dependent: :destroy
  has_many :sessions, dependent: :destroy
end
```

### Belongs To

```ruby
class Workspace < ApplicationRecord
  belongs_to :user
end
```

### Has Many Through

```ruby
class User < ApplicationRecord
  has_many :workspaces, dependent: :destroy
  has_many :links, through: :workspaces
end
```

### Dependent Options

- `dependent: :destroy` - Delete associated records
- `dependent: :nullify` - Set foreign key to NULL
- `dependent: :restrict_with_error` - Prevent deletion if associations exist

## Validations

```ruby
class Link < ApplicationRecord
  validates :slug, presence: true, uniqueness: true
  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp }
  validates :name, length: { maximum: 255 }
end
```

### Common Validators

```ruby
validates :email, presence: true
validates :email, uniqueness: true
validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
validates :name, length: { minimum: 2, maximum: 100 }
validates :status, inclusion: { in: %w[active inactive] }
validates :count, numericality: { only_integer: true, greater_than: 0 }
```

## Normalizations (Rails 7.1+)

Automatically transform attributes before saving:

```ruby
class User < ApplicationRecord
  normalizes :email, with: ->(e) { e.strip.downcase }
end

# Usage
user = User.new(email: "  FOO@BAR.COM  ")
user.email  # => "foo@bar.com"
```

## Enums

```ruby
class User < ApplicationRecord
  enum :role, [ :user, :admin ]
end

# Usage
user.admin?       # => true/false
user.admin!       # Sets role to admin
User.admin        # Scope for admin users
```

### With Explicit Values

```ruby
enum :status, { draft: 0, published: 1, archived: 2 }
```

## CurrentAttributes

`app/models/current.rb` provides request-scoped global state:

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :session
  delegate :user, to: :session, allow_nil: true
end
```

Access anywhere:

```ruby
Current.user          # Current logged-in user
Current.session       # Current session record
```

## Scopes

```ruby
class Visit < ApplicationRecord
  scope :processed, -> { where.not(processed_at: nil) }
  scope :unprocessed, -> { where(processed_at: nil) }
  scope :recent, -> { order(created_at: :desc).limit(100) }
  scope :for_link, ->(link_id) { where(link_id: link_id) }
end
```

## Callbacks

```ruby
class Link < ApplicationRecord
  before_validation :generate_slug, on: :create
  after_create :sync_social_tags

  private

  def generate_slug
    self.slug ||= SecureRandom.alphanumeric(6)
  end

  def sync_social_tags
    SyncSocialTagJob.perform_later(self)
  end
end
```

## Class Methods

```ruby
class Workspace < ApplicationRecord
  def self.event_limit_reached?(workspace_id)
    workspace = find(workspace_id)
    workspace.visits_count >= workspace.plan_limit
  end
end
```

## Instance Methods

Keep business logic in models:

```ruby
class User < ApplicationRecord
  def logged_in!
    self.last_login_at = Time.current
    save!
  end
end

class Link < ApplicationRecord
  def domain_url
    "#{workspace.domain || 'ugo.cr'}/#{slug}"
  end
end
```

## Queries

### Finding Records

```ruby
User.find(1)                    # Raises if not found
User.find_by(email: "a@b.com")  # Returns nil if not found
User.find_by!(email: "a@b.com") # Raises if not found
```

### Chaining

```ruby
Link.where(workspace_id: 1)
    .where("created_at > ?", 1.week.ago)
    .order(created_at: :desc)
    .limit(10)
```

### Includes (N+1 Prevention)

```ruby
# Bad - N+1 queries
Link.all.each { |link| puts link.workspace.name }

# Good - Eager loading
Link.includes(:workspace).each { |link| puts link.workspace.name }
```

## Migrations

```ruby
class CreateLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :links do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name
      t.string :slug, null: false
      t.string :url

      t.timestamps
    end

    add_index :links, :slug, unique: true
  end
end
```

## Key Conventions

- Keep models focused on data and business logic
- Use `normalizes` for attribute transformations
- Use `dependent: :destroy` to clean up associations
- Use scopes for reusable query logic
- Use `find_by!` when record must exist
- Use `includes` to prevent N+1 queries
- Prefer `Time.current` over `Time.now` for timezone awareness
