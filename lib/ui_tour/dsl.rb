require "fileutils"

module UiTour
  # Tiny DSL on top of Capybara. Tour scripts (under tours/) declare scenes,
  # each scene visits something and calls `snapshot` to capture a screenshot.
  #
  # Example:
  #   Tour.script "Logged-out marketing" do
  #     scene "Home" do
  #       visit "/"
  #       expect_text "Shorten links"
  #       snapshot
  #     end
  #   end
  module DSL
    class Script
      attr_reader :title, :scenes, :options

      def initialize(title, **options, &block)
        @title = title
        @scenes = []
        @options = options
        @block = block
        @modes = Array(options[:modes]).map(&:to_sym)
      end

      # Returns true if this script should run under the given app mode
      # (main_app or self_hosted). Scripts that don't declare modes apply to all.
      def runs_in?(mode)
        @modes.empty? || @modes.include?(mode.to_sym)
      end

      def build!(context)
        @context = context
        instance_eval(&@block)
        self
      end

      # Pre-authenticate as a known fixture user before the script runs.
      # Available sessions are defined in UiTour::SessionPool.
      def use_session(name)
        @session_name = name
      end

      def session_name
        @session_name
      end

      def scene(name, &block)
        @scenes << Scene.new(self, name, &block)
      end
    end

    class Scene
      attr_reader :script, :name, :block

      def initialize(script, name, &block)
        @script = script
        @name = name
        @block = block
      end

      def run!(runner)
        SceneContext.new(runner, self).instance_eval(&@block)
      end
    end

    # Per-scene execution context. Wraps the live Capybara session so scene
    # blocks read like Capybara DSL plus a few smoke helpers and `snapshot`.
    class SceneContext
      def initialize(runner, scene)
        @runner = runner
        @scene = scene
        @session = runner.session
      end

      # ---- Capybara passthroughs --------------------------------------------
      def visit(path)
        @session.visit(path)
        wait_for_idle
      end

      def click_link(*args, **opts)
        @session.click_link(*args, **opts)
        wait_for_idle
      end

      def click_button(*args, **opts)
        @session.click_button(*args, **opts)
        wait_for_idle
      end

      def click_on(*args, **opts)
        @session.click_on(*args, **opts)
        wait_for_idle
      end

      def fill_in(locator, with:)
        @session.fill_in(locator, with: with)
      end

      def select(value, from:)
        @session.select(value, from: from)
      end

      def find(*args, **opts)
        @session.find(*args, **opts)
      end

      def page
        @session
      end

      # ---- Smoke assertions --------------------------------------------------
      def expect_text(text)
        return if @session.has_text?(text, wait: 5)
        raise SmokeFailure, "expected text #{text.inspect} to appear in #{@session.current_path}"
      end

      def expect_no_text(text)
        return if @session.has_no_text?(text, wait: 1)
        raise SmokeFailure, "expected text #{text.inspect} NOT to appear in #{@session.current_path}"
      end

      def expect_selector(selector, **opts)
        return if @session.has_selector?(selector, wait: 5, **opts)
        raise SmokeFailure, "expected selector #{selector.inspect} on #{@session.current_path}"
      end

      # ---- Capture -----------------------------------------------------------
      # Take a screenshot. Options:
      #   caption:   override the auto-derived caption
      #   full_page: capture the entire scrollable page (default true)
      #   viewport:  :desktop (default) or :mobile — switches window size before capturing
      #   pause:     wait N seconds before capturing (use for CSS fade-ins, charts loading)
      def snapshot(caption: nil, full_page: true, viewport: :desktop, pause: nil)
        @runner.with_viewport(viewport) do
          sleep(pause) if pause
          @runner.capture(
            script_title: @scene.script.title,
            scene_name: @scene.name,
            caption: caption,
            full_page: full_page,
            viewport: viewport
          )
        end
      end

      # Disable / re-enable JavaScript execution from the HTML source for
      # subsequent navigations. Useful for capturing pages that would
      # otherwise immediately auto-redirect via window.location (e.g. the
      # links#link splash). Re-enabling is the caller's responsibility.
      def disable_javascript
        @session.driver.browser.page.command("Emulation.setScriptExecutionDisabled", value: true)
      end

      def enable_javascript
        @session.driver.browser.page.command("Emulation.setScriptExecutionDisabled", value: false)
      end

      private

      # Hotwire/Turbo can leave navigations momentarily pending after a click.
      # A small wait avoids racing screenshots.
      def wait_for_idle
        @session.has_css?("body", wait: 5)
      end
    end

    class SmokeFailure < StandardError; end
  end

  # Public entry point used by tour scripts.
  module Tour
    def self.scripts
      @scripts ||= []
    end

    def self.script(title, **options, &block)
      scripts << DSL::Script.new(title, **options, &block)
    end

    def self.reset!
      @scripts = []
    end
  end
end
