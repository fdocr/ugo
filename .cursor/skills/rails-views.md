# Rails Views

## File Structure

```
app/views/
  layouts/
    application.html.erb      # Main layout
    mailer.html.erb          # Email layout
  shared/
    _nav.html.erb            # Navigation partial
    _flash.html.erb          # Flash messages
    _link.html.erb           # Reusable link partial
    svg/                     # SVG icon partials
      _add.html.erb
      _edit.html.erb
      _delete.html.erb
  [controller]/
    index.html.erb
    show.html.erb
    edit.html.erb
    _form.html.erb           # Form partial
```

## Layout Structure

```erb
<!-- app/views/layouts/application.html.erb -->
<!DOCTYPE html>
<html lang="en">
  <head>
    <title><%= @page_title || "App Name" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= stylesheet_link_tag "tailwind", "inter-font", "data-turbo-track": "reload" %>
    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body class="bg-background">
    <%= render "shared/nav" %>

    <main class="container mx-auto mt-12 px-4 pb-16">
      <%= render "shared/flash" %>
      <%= yield %>
    </main>
  </body>
</html>
```

## Tailwind CSS Semantic Classes

Use these semantic color classes defined in `app/assets/tailwind/application.css`:

### Backgrounds
- `bg-background` - Page background
- `bg-card` - Card/panel background
- `bg-accent` - Hover/active states
- `bg-muted` - Subtle backgrounds
- `bg-primary-600` - Primary buttons
- `bg-destructive` - Danger actions

### Text
- `text-foreground` - Primary text
- `text-muted-foreground` - Secondary/subtle text
- `text-card-foreground` - Text on cards
- `text-accent-foreground` - Text on accent backgrounds

### Borders
- `border` - Default subtle border (uses `--color-border`)
- `border-input` - Form input borders
- `border-destructive` - Danger borders

### Focus States
- `focus:ring-ring` - Focus ring color
- `ring-offset-background` - Ring offset color

## Common Patterns

### Page with Card

```erb
<div class="space-y-6 mx-auto w-full max-w-5xl">
  <div class="space-y-2">
    <h1 class="text-2xl font-semibold">Page Title</h1>
    <p class="text-muted-foreground">Page description</p>
  </div>

  <div class="rounded-lg border bg-card text-card-foreground shadow-lg">
    <div class="p-6">
      <!-- Card content -->
    </div>
  </div>
</div>
```

### Card with Items

```erb
<div class="rounded-lg border bg-card shadow-lg">
  <div class="p-6">
    <h3 class="text-lg font-semibold mb-4">Section Title</h3>
    
    <div class="space-y-3">
      <% @items.each do |item| %>
        <div class="p-4 rounded-lg border hover:bg-accent/50 transition-colors">
          <h4 class="font-medium"><%= item.name %></h4>
          <p class="text-sm text-muted-foreground"><%= item.description %></p>
        </div>
      <% end %>
    </div>
  </div>
</div>
```

### Button Styles

```erb
<!-- Primary Button -->
<%= link_to "Action", path, 
    class: "inline-flex items-center justify-center rounded-md bg-primary-600 px-4 py-2 text-sm font-medium text-white shadow hover:bg-primary/90 focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2" %>

<!-- Secondary Button -->
<%= link_to "Cancel", path,
    class: "inline-flex items-center justify-center rounded-md border border-input bg-background px-4 py-2 text-sm font-medium shadow-sm hover:bg-accent hover:text-accent-foreground" %>

<!-- Danger Button -->
<%= button_to "Delete", path, method: :delete,
    class: "inline-flex items-center justify-center rounded-md bg-red-600 px-4 py-2 text-sm font-medium text-white shadow hover:bg-red-700" %>
```

## Partials

### Rendering Partials

```erb
<!-- Simple partial -->
<%= render "shared/nav" %>

<!-- Partial with local variables -->
<%= render "shared/link", link: @link %>

<!-- Collection partial -->
<%= render partial: "links/link", collection: @links, as: :link %>

<!-- Partial with layout -->
<%= render partial: "form", layout: "card" %>
```

### Partial Naming

- Partial files start with underscore: `_form.html.erb`
- Reference without underscore: `render "form"`
- Shared partials in `app/views/shared/`

### SVG Partials

```erb
<!-- app/views/shared/svg/_edit.html.erb -->
<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="<%= local_assigns[:class] || 'w-5 h-5' %>">
  <path stroke-linecap="round" stroke-linejoin="round" d="..." />
</svg>

<!-- Usage -->
<%= render "shared/svg/edit", class: "w-4 h-4" %>
```

## Forms

### Form Builder

```erb
<%= form_with model: @link, url: workspace_link_path(@workspace.slug, @link.slug) do |form| %>
  <div class="space-y-4">
    <div>
      <%= form.label :name, class: "block text-sm font-medium mb-1" %>
      <%= form.text_field :name, 
          class: "w-full rounded-md border border-input bg-background px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-ring" %>
    </div>

    <div>
      <%= form.label :url, class: "block text-sm font-medium mb-1" %>
      <%= form.url_field :url,
          class: "w-full rounded-md border border-input bg-background px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-ring" %>
    </div>

    <%= form.submit "Save",
        class: "inline-flex items-center justify-center rounded-md bg-primary-600 px-4 py-2 text-sm font-medium text-white shadow hover:bg-primary/90" %>
  </div>
<% end %>
```

### Turbo Forms

```erb
<!-- Remote form (default in Rails 7+) -->
<%= form_with model: @link do |form| %>
  <!-- Submits via Turbo by default -->
<% end %>

<!-- Local form (full page reload) -->
<%= form_with model: @link, local: true do |form| %>
<% end %>
```

## Flash Messages

```erb
<!-- app/views/shared/_flash.html.erb -->
<% flash.each do |type, message| %>
  <div class="mb-4 p-4 rounded-lg <%= type == 'alert' ? 'bg-red-100 text-red-700' : 'bg-green-100 text-green-700' %>">
    <%= message %>
  </div>
<% end %>
```

## Conditional Rendering

```erb
<% if authenticated? %>
  <%= link_to "Dashboard", dashboard_path %>
<% else %>
  <%= link_to "Sign In", new_session_path %>
<% end %>

<% if @link.url.present? %>
  <p><%= @link.url %></p>
<% else %>
  <p class="text-muted-foreground">No URL set</p>
<% end %>
```

## Content Helpers

```erb
<!-- Truncate -->
<%= truncate(@link.name, length: 50) %>

<!-- Pluralize -->
<%= pluralize(@workspace.links.count, 'link') %>

<!-- Time formatting -->
<%= time_ago_in_words(@link.created_at) %> ago

<!-- Number formatting -->
<%= number_with_delimiter(@visits_count) %>
```

## Turbo Frames

```erb
<!-- Wrap content in a frame -->
<%= turbo_frame_tag "link_#{@link.id}" do %>
  <div class="p-4">
    <%= @link.name %>
    <%= link_to "Edit", edit_workspace_link_path(@workspace.slug, @link.slug) %>
  </div>
<% end %>
```

## Key Conventions

- Use semantic Tailwind classes (`bg-card`, `text-muted-foreground`)
- Keep partials small and reusable
- Use `render` for partials, not `render partial:`
- Store shared partials in `app/views/shared/`
- Store SVG icons in `app/views/shared/svg/`
- Use `form_with` for all forms (Turbo-enabled by default)
- Use `data-turbo-track: "reload"` for stylesheets
