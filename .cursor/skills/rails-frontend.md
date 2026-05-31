# Rails Frontend

This project uses a zero-build JavaScript setup with Tailwind CSS compilation.

## Architecture Overview

| Component | Purpose | Build Required |
|-----------|---------|----------------|
| Propshaft | Asset fingerprinting & serving | No |
| Importmaps | JavaScript module loading | No |
| Tailwind CSS v4 | CSS compilation | Yes (auto in dev) |
| Hotwire | SPA-like interactivity | No |

## Importmaps

### Configuration

```ruby
# config/importmap.rb
pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "@hotwired--stimulus.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# Third-party packages
pin "@stimulus-components/dropdown", to: "@stimulus-components--dropdown.js"
pin "@stimulus-components/clipboard", to: "@stimulus-components--clipboard.js"
pin "stimulus-use"
```

### Adding Packages

```bash
# Pin from CDN
bin/importmap pin package-name

# Pin and download to vendor/javascript
bin/importmap pin package-name --download

# Check for outdated packages
bin/importmap outdated
```

### Vendored Packages

Downloaded packages live in `vendor/javascript/`:

```
vendor/javascript/
  @hotwired--stimulus.js
  @stimulus-components--dropdown.js
  @stimulus-components--clipboard.js
  stimulus-use.js
```

## Stimulus Controllers

### File Location

```
app/javascript/
  application.js
  controllers/
    application.js
    index.js
    filter_controller.js
    map_controller.js
```

### Controller Structure

```javascript
// app/javascript/controllers/example_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "output"];
  static values = { url: String, count: Number };
  static outlets = ["other-controller"];

  connect() {
    // Called when controller connects to DOM
  }

  disconnect() {
    // Called when controller disconnects
  }

  // Action methods
  submit(event) {
    event.preventDefault();
    this.outputTarget.textContent = this.inputTarget.value;
  }

  // Value changed callbacks
  countValueChanged() {
    console.log("Count is now", this.countValue);
  }
}
```

### HTML Usage

```erb
<div data-controller="example" 
     data-example-url-value="<%= api_path %>"
     data-example-count-value="0">
  
  <input data-example-target="input" type="text">
  
  <button data-action="click->example#submit">
    Submit
  </button>
  
  <div data-example-target="output"></div>
</div>
```

### Targets

```javascript
static targets = ["input", "list", "item"];

// Single target
this.inputTarget          // First matching element
this.hasInputTarget       // Boolean check

// Multiple targets
this.itemTargets          // Array of all matching
this.itemTargetElements   // Same as above
```

### Values

```javascript
static values = { 
  url: String,
  count: Number,
  enabled: Boolean,
  config: Object,
  items: Array
};

// Access
this.urlValue             // Get value
this.urlValue = "/new"    // Set value
this.hasUrlValue          // Boolean check
```

### Actions

```erb
<!-- Click -->
<button data-action="click->controller#method">

<!-- Multiple actions -->
<button data-action="click->a#one click->b#two">

<!-- Other events -->
<input data-action="input->controller#search">
<form data-action="submit->controller#save">
<div data-action="mouseenter->controller#show mouseleave->controller#hide">
```

### Outlets (Controller Communication)

```javascript
// Parent controller
static outlets = ["child"];

this.childOutlet           // First child controller
this.childOutlets          // All child controllers
this.hasChildOutlet        // Boolean check

// Call methods on outlet
this.childOutlet.refresh();
```

```erb
<div data-controller="parent" data-parent-child-outlet=".child-element">
  <div class="child-element" data-controller="child">
  </div>
</div>
```

## Turbo

### Turbo Drive

Enabled by default. All link clicks and form submissions are handled via fetch.

```erb
<!-- Disable for specific link -->
<a href="/path" data-turbo="false">Regular link</a>

<!-- Disable for form -->
<%= form_with model: @item, data: { turbo: false } do |f| %>
```

### Turbo Frames

```erb
<%= turbo_frame_tag "item_#{@item.id}" do %>
  <div class="item">
    <%= @item.name %>
    <%= link_to "Edit", edit_item_path(@item) %>
  </div>
<% end %>
```

### Turbo Streams

```erb
<!-- app/views/items/create.turbo_stream.erb -->
<%= turbo_stream.append "items" do %>
  <%= render @item %>
<% end %>

<%= turbo_stream.update "counter", @items.count %>
```

## Tailwind CSS v4

Make sure UI styles applied are consistent across other views in the project. Border radius, colors, element sizes, etc.

### Configuration

CSS-based configuration in `app/assets/tailwind/application.css`:

```css
@import "tailwindcss";

@source "../../views";
@source "../../helpers";
@source "../../javascript";

@theme {
  --color-primary: #5aa9e6;
  --color-primary-600: #2b73b8;
  --color-background: #ffffff;
  --color-foreground: #0f172a;
  --color-card: #ffffff;
  --color-muted-foreground: #64748b;
  --color-border: #e2e8f0;
  --font-sans: 'Inter', system-ui, sans-serif;
}

@layer base {
  *,
  ::after,
  ::before {
    border-color: var(--color-border);
  }
}
```

### Development

Tailwind rebuilds automatically via Puma plugin:

```ruby
# config/puma.rb
plugin :tailwindcss if ENV.fetch("RAILS_ENV", "development") == "development"
```

Just run `bin/rails server` - no separate process needed.

### Manual Build

```bash
bin/rails tailwindcss:build
```

### Adding Custom Colors

```css
@theme {
  --color-success: #22c55e;
  --color-success-50: #f0fdf4;
  --color-success-600: #16a34a;
}
```

Use in HTML: `bg-success`, `text-success-600`, etc.

## Asset Pipeline (Propshaft)

### How It Works

1. Propshaft serves files from `app/assets/` directly
2. Adds digest fingerprints for cache busting
3. No transpilation or bundling

### Asset Paths

```erb
<!-- Stylesheets -->
<%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>

<!-- Images -->
<%= image_tag "logo.png" %>
<%= asset_path "icon.svg" %>

<!-- In CSS -->
background-image: url('icon.png');  /* Propshaft resolves this */
```

### File Locations

```
app/assets/
  builds/              # Compiled Tailwind output
    tailwind.css
  images/
    logo.png
  stylesheets/
    application.css
    inter-font.css
  tailwind/
    application.css    # Tailwind source
```

## Key Conventions

- Make sure UI styles applied are consistent across other views in the project
- No webpack, esbuild, or node_modules
- Use Importmaps for JavaScript dependencies
- Vendor third-party JS in `vendor/javascript/`
- Use Stimulus for interactive components
- Use Turbo for navigation and updates
- Tailwind v4 uses CSS-based configuration
- One command (`bin/rails server`) starts everything
