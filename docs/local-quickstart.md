# Local Quickstart

This guide walks you through the setup up for development and overall details about the codebase.

## System Requirements

* Ruby 3.4.4+
* Rails 8.1+
* SQLite 2.1+

## Development Setup

1. **Copy `.env.sample` to `.env`**

   Several features expect values in `.env` (encryption keys, Polar, MaxMind, and more). Start from the sample file and fill in what you need as you go:

   ```bash
   cp .env.sample .env
   ```

2. **Install dependencies**
   ```bash
   bundle install
   ```

3. **Setup the database**
   ```bash
   bin/rails db:setup
   ```

4. **Download the GeoLite2 database**

   The GeoLite2-City database is required for IP geolocation during visit processing. If you have MaxMind credentials in your `.env`:
   ```bash
   bin/rails geolite2:download
   ```

   If you don't have credentials the task will print signup instructions. You can also download `GeoLite2-City.mmdb` manually from your [MaxMind account downloads page](https://www.maxmind.com/en/accounts/current/geoip/downloads) and place it in the project root.

5. **Start the development server**
   ```bash
   bin/rails s
   ```

## Frontend Architecture

* **Importmaps**: Used for JavaScript module imports without a bundler
* **Hotwire**: Turbo and Stimulus for SPA-like functionality
* **Stimulus.js**: For small, reusable JavaScript behaviors
* **Tailwind CSS v4**: CSS-based configuration in `app/assets/tailwind/application.css`

Key packages:
- Turbo Rails for page navigation
- Stimulus controllers for interactive elements
- Propshaft for asset pipeline
- No JS build process required thanks to importmaps

### Charts & Data Visualization

Analytics charts use **ApexCharts** for time-series and list visualizations, and **DataMaps** (D3-based) for the world map. These libraries are vendored in `vendor/javascript/` and loaded as global scripts via `javascript_include_tag` in the layout *before* importmaps. This approach is necessary because DataMaps and its dependencies (D3 v3, TopoJSON) are older libraries that expect globals rather than ES modules—they must be available before Stimulus controllers initialize.

Stimulus controllers in `app/javascript/controllers/` consume data passed via `data-*-value` attributes and render the visualizations. The devices and geo charts use a Plausible-inspired pure HTML/CSS list design rather than ApexCharts for better control over styling.

**Updating chart dependencies:**
1. Download the new version of the vendored dependency:
   - `curl -sL "https://cdn.jsdelivr.net/npm/apexcharts@4.5.0/dist/apexcharts.min.js" -o vendor/javascript/apexcharts.min.js`
   - `curl -sL "https://cdn.jsdelivr.net/npm/d3@3.5.17/d3.min.js" -o vendor/javascript/d3.v3.min.js`
   - `curl -sL "https://cdn.jsdelivr.net/npm/topojson@1.6.27/build/topojson.min.js" -o vendor/javascript/topojson.v1.min.js`
   - `curl -sL "https://cdn.jsdelivr.net/npm/datamaps@0.5.9/dist/datamaps.world.min.js" -o vendor/javascript/datamaps.world.min.js`
2. Test locally with `bin/rails s` and verify charts render correctly
3. Run `bin/rails test` to ensure nothing is broken

## Authentication & Authorization

This application uses Rails 8's built-in authentication with `has_secure_password` and a plain Ruby authorization pattern (no Pundit or CanCanCan gems).

**Workspace Authorization**: Access control is enforced through the `WorkspaceAuthorization` concern, which is included in controllers that manage workspace-scoped resources. The concern provides `authorize_workspace_member!` and `authorize_workspace_admin!` before actions that check the current user's membership and role. Workspaces have two roles: `admin` (can invite/remove members, edit settings) and `member` (read/write access to links and analytics). The `Membership` model connects users to workspaces with their assigned role.

Site-wide admin access is separate—stored as a `site_admin` boolean column on the users table and checked with `User#site_admin?`.

## Payments (Polar)

Subscriptions and payments are handled by [Polar](https://polar.sh). In production, Polar is configured through the admin panel. For local development, use the **Polar Sandbox** environment—a fully isolated instance where you can test purchases with Stripe test cards at no cost. Set the values in your `.env` file (they fall back to ENV when the database values are blank).

### Sandbox Setup

1. Create a sandbox account at [sandbox.polar.sh](https://sandbox.polar.sh/start) (separate from your production account)
2. Create an organization in the sandbox
3. Create two **products** (recurring, monthly): one for Basic ($9) and one for Growth ($19). Copy each product ID.
4. Generate an **Organization Access Token** from your sandbox organization settings
5. Add the following to your `.env`:
   ```
   POLAR_SANDBOX=true
   POLAR_ACCESS_TOKEN=<your sandbox OAT>
   POLAR_BASIC_PRODUCT_ID=<your sandbox Basic product ID>
   POLAR_GROWTH_PRODUCT_ID=<your sandbox Growth product ID>
   POLAR_WEBHOOK_SECRET=<filled in next step>
   ```

### Webhook Testing with Polar CLI

The Polar CLI includes a `listen` command that relays webhook events from your sandbox organization to your local Rails server—no ngrok or external tunnel required.

1. Install the Polar CLI:
   ```bash
   curl -fsSL https://polar.sh/install.sh | bash
   ```

2. Start the webhook relay pointing at the local webhooks route:
   ```bash
   polar listen http://localhost:3000/webhooks/polar
   ```

3. The CLI will prompt you to select your sandbox organization and then print output like:
   ```
   ✔ Select Organization …  My Organization

     Connected  My Organization
     Secret     6t3c8ce2247c493a3ade20uea4484d64
     Forwarding http://localhost:3000/webhooks/polar

     Waiting for events...
   ```

4. Copy the **Secret** value and set it as `POLAR_WEBHOOK_SECRET` in your `.env`
5. Restart your Rails server so it picks up the new secret

The CLI session must stay running in a separate terminal while you test. Webhook events will appear in the CLI output as they are forwarded.

### End-to-End Test Flow

With both `bin/rails s` and `polar listen` running:

1. Sign in and create (or navigate to) a workspace
2. Go to the workspace checkout page
3. Complete payment using Stripe's test card number: `4242 4242 4242 4242` (any future expiry, any CVC)
4. Watch the `polar listen` terminal—you should see `subscription.active` and `order.paid` events forwarded
5. After the checkout success page, verify the workspace plan upgraded to Basic on the billing page
6. Invoice emails are viewable locally via `letter_opener` (opens in browser automatically in development)
7. Test cancellation from the billing page and confirm the workspace downgrades to Free

### Key Files

| File | Purpose |
|------|---------|
| `config/initializers/polar.rb` | Configures the `polar_sh` gem (access token, sandbox mode, webhook secret) |
| `app/controllers/webhooks/polar_controller.rb` | Receives and verifies webhook events, updates subscriptions/payments |
| `app/controllers/checkout_controller.rb` | Creates Polar checkout sessions, renders embedded checkout |
| `app/controllers/billing_controller.rb` | Billing overview and subscription cancellation |
| `app/models/subscription.rb` | Subscription record tied to a workspace |
| `app/models/payment.rb` | Individual payment records linked to subscriptions |

## UI Styleguide

A development-only reference for the design system lives at
[`/dev/styleguide`](http://localhost:3000/dev/styleguide). It showcases the color
tokens, typography, buttons, badges, banners, form controls, cards, stats, empty
and loading states, tabs, segmented controls, and tables that the rest of the
app composes from. The route is registered only when `Rails.env.development?` is
true and the controller additionally returns 404 if hit in any other environment,
so it never reaches production.

When you reach for a new visual pattern, prefer one of the building blocks under
`app/views/ui/*` and `app/assets/tailwind/application.css`. Add new primitives
there (and a swatch on the styleguide) instead of bespoke Tailwind class strings
in views.

## UI Smoke Tour

`bin/ui-tour` is a reusable visual smoke-test runner. It boots the app in a
dedicated `tour` Rails environment (its own SQLite file under `storage/`),
seeds a deterministic set of users / workspaces / billing states, drives a
headless Chrome browser through every common screen, and writes a numbered
slideshow to `tmp/ui-tour/index.html` you can open locally.

```bash
bin/ui-tour            # full tour, headless, default main_app mode
bin/ui-tour --open     # also pop the slideshow open when done
bin/ui-tour --help     # full flag reference
```

Useful flags:

- `--mode=self_hosted` — re-seed and screenshot the self-hosted UI variant
- `--only=Billing,Link` — run only matching tour scripts
- `--headed --slowmo=0.5` — show the browser and slow it down so you can watch

Tour scripts live in `tours/*.rb` and use a tiny Capybara DSL (`scene`,
`visit`, `expect_text`, `snapshot`). Add a new file to cover a new screen —
the runner picks it up automatically and assigns the next global screenshot
number. Failed smoke checks save an error screenshot but don't abort unless
you pass `--fail-fast`. Billing flows are screenshot from pre-seeded
subscription rows (active / past_due / cancelled / expired-trial) — the live
Polar checkout iframe is documented separately under [Payments (Polar)](#payments-polar)
and intentionally skipped here.
