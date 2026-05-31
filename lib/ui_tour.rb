# UI Tour: drives a headless browser through a deterministic seed of the app
# and captures numbered screenshots into a self-contained slideshow.
# Entry point: bin/ui-tour. See docs/local-quickstart.md for usage.
module UiTour
  autoload :DSL,         "ui_tour/dsl"
  autoload :Tour,        "ui_tour/dsl"
  autoload :Fixtures,    "ui_tour/fixtures"
  autoload :SessionPool, "ui_tour/session_pool"
  autoload :Slideshow,   "ui_tour/slideshow"
  autoload :Runner,      "ui_tour/runner"
end

# Make the top-level `Tour` constant available inside tour scripts without
# requiring callers to write `UiTour::Tour`.
Tour = UiTour::Tour unless defined?(Tour)
