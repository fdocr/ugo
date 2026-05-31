# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Seeding database..."

# Mark setup as completed so the setup wizard is skipped
config = AppConfig.shared
unless config.setup_completed
  config.update!(
    setup_completed: true,
    app_name: "ugo (dev)",
    app_domain: "localhost:3000"
  )
  puts "  App config: setup marked as completed"
end

# Create admin user with site_admin privileges
user = User.find_or_create_by!(email: "admin@fdo.cr") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
  u.site_admin = true
end
# Ensure site_admin is set even if user already exists
user.update!(site_admin: true) unless user.site_admin?
puts "  Created user: #{user.email} (site_admin: #{user.site_admin?})"

# Create workspace (automatically creates owner membership).
# On the main app (ugo.cr), new workspaces get a trial via callback.
# In dev (localhost), AppConfig may be set to ugo.cr from a prior seed
# run, so we explicitly ensure the trial window is set for a realistic
# managed ugo.cr-style development experience.
workspace = Workspace.find_or_create_by!(user: user) do |w|
  w.name = "Demo"
end
if AppConfig.main_app? && workspace.trial_ends_at.blank? && !workspace.paying?
  workspace.update!(trial_ends_at: Workspace.trial_duration_days.days.from_now)
end
puts "  Created workspace: #{workspace.name} (plan: #{workspace.plan}, trial?: #{workspace.trial?})"

def find_or_create_seed_link!(workspace:, name:, url:, comments: nil)
  link = workspace.links.find_or_initialize_by(name: name)
  return link unless link.new_record?

  link.url = url
  link.comments = comments
  link.save_with_new_slug
  raise ActiveRecord::RecordInvalid, link unless link.persisted?

  link
end

# Create two links (slug generated like Link#save_with_new_slug in LinksController#create)
link1 = find_or_create_seed_link!(
  workspace: workspace,
  name: "Product Launch",
  url: "https://example.com/product",
  comments: "Main product landing page"
)
puts "  Created link: #{link1.name} (#{link1.slug})"

link2 = find_or_create_seed_link!(
  workspace: workspace,
  name: "Blog Article",
  url: "https://example.com/blog/getting-started",
  comments: "Popular blog post"
)
puts "  Created link: #{link2.name} (#{link2.slug})"

# Sample data for realistic visits
COUNTRIES = [
  { country: "United States", country_code: "US", cities: [ "New York", "Los Angeles", "Chicago", "Houston", "Phoenix" ], subdivisions: [ "New York", "California", "Illinois", "Texas", "Arizona" ], weight: 35 },
  { country: "United Kingdom", country_code: "GB", cities: [ "London", "Manchester", "Birmingham", "Leeds", "Glasgow" ], subdivisions: [ "England", "Scotland", "Wales" ], weight: 12 },
  { country: "Germany", country_code: "DE", cities: [ "Berlin", "Munich", "Hamburg", "Frankfurt", "Cologne" ], subdivisions: [ "Berlin", "Bavaria", "Hamburg", "Hesse" ], weight: 10 },
  { country: "Canada", country_code: "CA", cities: [ "Toronto", "Vancouver", "Montreal", "Calgary", "Ottawa" ], subdivisions: [ "Ontario", "British Columbia", "Quebec", "Alberta" ], weight: 8 },
  { country: "France", country_code: "FR", cities: [ "Paris", "Lyon", "Marseille", "Toulouse", "Nice" ], subdivisions: [ "Île-de-France", "Auvergne-Rhône-Alpes", "Provence-Alpes-Côte d'Azur" ], weight: 7 },
  { country: "Australia", country_code: "AU", cities: [ "Sydney", "Melbourne", "Brisbane", "Perth", "Adelaide" ], subdivisions: [ "New South Wales", "Victoria", "Queensland", "Western Australia" ], weight: 6 },
  { country: "Netherlands", country_code: "NL", cities: [ "Amsterdam", "Rotterdam", "The Hague", "Utrecht" ], subdivisions: [ "North Holland", "South Holland", "Utrecht" ], weight: 5 },
  { country: "Spain", country_code: "ES", cities: [ "Madrid", "Barcelona", "Valencia", "Seville" ], subdivisions: [ "Madrid", "Catalonia", "Valencia", "Andalusia" ], weight: 4 },
  { country: "Brazil", country_code: "BR", cities: [ "São Paulo", "Rio de Janeiro", "Brasília", "Salvador" ], subdivisions: [ "São Paulo", "Rio de Janeiro", "Federal District", "Bahia" ], weight: 4 },
  { country: "India", country_code: "IN", cities: [ "Mumbai", "Delhi", "Bangalore", "Chennai" ], subdivisions: [ "Maharashtra", "Delhi", "Karnataka", "Tamil Nadu" ], weight: 3 },
  { country: "Japan", country_code: "JP", cities: [ "Tokyo", "Osaka", "Yokohama", "Nagoya" ], subdivisions: [ "Tokyo", "Osaka", "Kanagawa", "Aichi" ], weight: 3 },
  { country: "Costa Rica", country_code: "CR", cities: [ "San José", "Alajuela", "Cartago", "Heredia" ], subdivisions: [ "San José", "Alajuela", "Cartago", "Heredia" ], weight: 2 },
  { country: "Mexico", country_code: "MX", cities: [ "Mexico City", "Guadalajara", "Monterrey", "Cancún" ], subdivisions: [ "Mexico City", "Jalisco", "Nuevo León", "Quintana Roo" ], weight: 1 }
].freeze

DEVICES = [
  { type: "desktop", weight: 55 },
  { type: "mobile", weight: 40 },
  { type: "tablet", weight: 5 }
].freeze

BROWSERS = [
  { name: "Chrome", weight: 65 },
  { name: "Safari", weight: 20 },
  { name: "Firefox", weight: 8 },
  { name: "Edge", weight: 5 },
  { name: "Opera", weight: 2 }
].freeze

OS_NAMES = [
  { name: "Windows", weight: 45 },
  { name: "macOS", weight: 25 },
  { name: "iOS", weight: 15 },
  { name: "Android", weight: 12 },
  { name: "Linux", weight: 3 }
].freeze

REFERERS = [
  { referer: "https://google.com", weight: 40 },
  { referer: "https://twitter.com", weight: 15 },
  { referer: "https://linkedin.com", weight: 12 },
  { referer: "https://facebook.com", weight: 10 },
  { referer: "https://reddit.com", weight: 8 },
  { referer: nil, weight: 15 } # Direct traffic
].freeze

USER_AGENTS = [
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
  "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
  "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0",
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
].freeze

def weighted_sample(items)
  total_weight = items.sum { |item| item[:weight] }
  random = rand * total_weight
  cumulative = 0

  items.each do |item|
    cumulative += item[:weight]
    return item if random <= cumulative
  end

  items.last
end

def generate_ip
  "#{rand(1..223)}.#{rand(0..255)}.#{rand(0..255)}.#{rand(1..254)}"
end

def create_visits_for_link(link, total_visits, days_back)
  puts "  Generating #{total_visits} visits for #{link.name}..."

  visits = []
  total_visits.times do
    # Random timestamp within the date range, weighted toward recent days
    days_ago = (rand ** 1.5 * days_back).to_i # Exponential distribution favoring recent
    hours_ago = rand(0..23)
    minutes_ago = rand(0..59)
    timestamp = days_ago.days.ago - hours_ago.hours - minutes_ago.minutes

    country_data = weighted_sample(COUNTRIES)
    device = weighted_sample(DEVICES)
    browser = weighted_sample(BROWSERS)
    os = weighted_sample(OS_NAMES)
    referer_data = weighted_sample(REFERERS)

    visits << {
      visitable_type: "Link",
      visitable_id: link.id,
      ip_address: generate_ip,
      user_agent: USER_AGENTS.sample,
      timestamp: timestamp,
      processed_at: timestamp + rand(1..30).seconds,
      country: country_data[:country],
      country_code: country_data[:country_code],
      city: country_data[:cities].sample,
      subdivision: country_data[:subdivisions].sample,
      device_type: device[:type],
      browser_name: browser[:name],
      os_name: os[:name],
      referer: referer_data[:referer],
      # Pool of ~1/3 the visit count so the dashboard shows a believable
      # unique-visitor to total-visit ratio.
      visitor_hash: "seed#{rand(1..(total_visits / 3).clamp(1, total_visits)).to_s.rjust(28, "0")}",
      latitude: rand(-90.0..90.0).round(6),
      longitude: rand(-180.0..180.0).round(6),
      accuracy_radius: [ 5, 10, 20, 50, 100 ].sample
    }
  end

  # Bulk insert for performance
  Visit.insert_all(visits)
end

# Clear existing visits for these links (for re-seeding)
Visit.where(visitable_type: "Link", visitable_id: [ link1.id, link2.id ]).delete_all

# Link 1: More popular, more visits (150-250 visits over 30 days)
create_visits_for_link(link1, rand(150..250), 30)

# Link 2: Less popular, fewer visits (50-100 visits over 30 days)
create_visits_for_link(link2, rand(50..100), 30)

puts "\nSeeding complete!"
puts "  Total visits: #{Visit.count}"
puts "  Login with: admin@fdo.cr / password123"
