require "fileutils"
require "json"

module UiTour
  class Runner
    DEFAULT_OUTPUT_DIR = "tmp/ui-tour".freeze
    SCREENSHOT_DIR = "screenshots".freeze
    DESKTOP_SIZE = [ 1400, 900 ].freeze
    MOBILE_SIZE = [ 390, 844 ].freeze

    attr_reader :session

    def initialize(options)
      @options = options
      @manifest = []
      @counter = 0
    end

    def run!
      prepare_output!
      load_tour_scripts!
      configure_capybara!

      mode_scripts = Tour.scripts.select { |s| s.runs_in?(@options[:mode]) }
      filtered_scripts = select_scripts(mode_scripts)
      raise "No tour scripts matched #{@options[:only].inspect}" if filtered_scripts.empty?

      filtered_scripts.each { |script| run_script!(script) }
      generate_slideshow!
      maybe_open!
      print_summary
    ensure
      teardown_capybara!
    end

    # Called by SceneContext#snapshot.
    def capture(script_title:, scene_name:, caption:, full_page:, viewport:)
      @counter += 1
      number = format("%03d", @counter)
      slug = "#{script_title}-#{scene_name}".downcase.gsub(/[^a-z0-9]+/, "-").gsub(/(^-|-$)/, "")[0, 60]
      file = "#{number}-#{slug}.png"
      full_path = File.join(@output_dir, SCREENSHOT_DIR, file)

      session.save_screenshot(full_path, full: full_page)

      @manifest << {
        "number" => @counter,
        "file" => file,
        "script_title" => script_title,
        "scene_name" => scene_name,
        "caption" => caption,
        "viewport" => viewport.to_s,
        "captured_at" => Time.now.iso8601
      }

      log "  [#{number}] #{script_title} · #{scene_name} (#{viewport})"
    end

    # Called by SceneContext#snapshot to apply a viewport before capturing.
    def with_viewport(viewport)
      original = @current_viewport
      apply_viewport(viewport)
      yield
    ensure
      apply_viewport(original) if original && original != viewport
    end

    private

    def log(msg)
      puts msg unless @options[:quiet]
    end

    def prepare_output!
      @output_dir = File.expand_path(@options[:output] || DEFAULT_OUTPUT_DIR, Rails.root)
      FileUtils.rm_rf(@output_dir)
      FileUtils.mkdir_p(File.join(@output_dir, SCREENSHOT_DIR))
      log "Output: #{relative(@output_dir)}"
    end

    def load_tour_scripts!
      Tour.reset!
      tour_files = Dir[Rails.root.join("tours", "*.rb")].sort
      tour_files.each { |f| load f }
      log "Loaded #{Tour.scripts.size} tour scripts"
    end

    def select_scripts(scripts)
      only = @options[:only]
      return scripts unless only && !only.empty?

      patterns = Array(only)
      scripts.select do |s|
        patterns.any? do |p|
          s.title.downcase.include?(p.downcase) ||
            File.basename(s.title).downcase.include?(p.downcase)
        end
      end
    end

    def configure_capybara!
      require "capybara"
      require "capybara/cuprite"

      browser_opts = {
        window_size: DESKTOP_SIZE,
        process_timeout: 20,
        timeout: 15,
        headless: !@options[:headed],
        slowmo: @options[:slowmo].to_f
      }

      Capybara.register_driver :ui_tour do |app|
        Capybara::Cuprite::Driver.new(app, browser_opts)
      end

      Capybara.app = Rails.application
      Capybara.default_driver = :ui_tour
      Capybara.javascript_driver = :ui_tour
      Capybara.default_max_wait_time = 5
      Capybara.server = :puma, { Silent: true }
      Capybara.server_host = "127.0.0.1"
      Capybara.run_server = true

      @session = Capybara::Session.new(:ui_tour, Rails.application)
      apply_viewport(:desktop)
    end

    def teardown_capybara!
      @session&.driver&.quit
    rescue StandardError
      # best effort
    end

    def apply_viewport(viewport)
      return unless @session
      size = (viewport == :mobile) ? MOBILE_SIZE : DESKTOP_SIZE
      @session.current_window.resize_to(*size)
      @current_viewport = viewport
    end

    def run_script!(script)
      log "\n→ #{script.title}"
      AppConfig.send(:reset_caches!)
      session.reset_session!

      # Evaluate the script block *first* — that's what populates `session_name`
      # via `use_session` — then sign in if needed before any scene runs.
      script.build!(self)
      SessionPool.login(session, script.session_name) if script.session_name

      script.scenes.each do |scene|
        scene.run!(self)
      rescue DSL::SmokeFailure => e
        log "  ⚠ smoke check failed in scene #{scene.name.inspect}: #{e.message}"
        capture_failure(script, scene, e)
        raise if @options[:fail_fast]
      rescue StandardError => e
        log "  ✗ scene crashed in #{scene.name.inspect}: #{e.class}: #{e.message}"
        capture_failure(script, scene, e)
        raise if @options[:fail_fast]
      end
    ensure
      SessionPool.logout(session) if script.session_name
    end

    def capture_failure(script, scene, error)
      capture(
        script_title: script.title,
        scene_name: scene.name,
        caption: "FAILURE: #{error.class}: #{error.message}",
        full_page: true,
        viewport: @current_viewport || :desktop
      )
    rescue StandardError
      # If the browser itself died we cannot capture; ignore.
    end

    def generate_slideshow!
      Slideshow.new(
        manifest: @manifest,
        output_dir: @output_dir,
        mode: @options[:mode],
        generated_at: Time.now
      ).generate!
      log "\nSlideshow: #{relative(File.join(@output_dir, "index.html"))}"
    end

    def maybe_open!
      return unless @options[:open]
      path = File.join(@output_dir, "index.html")
      case RbConfig::CONFIG["host_os"]
      when /darwin/ then system("open", path)
      when /linux/  then system("xdg-open", path)
      when /mswin|mingw|cygwin/ then system("start", path)
      end
    end

    def print_summary
      log "\nCaptured #{@manifest.size} screenshots across #{Tour.scripts.size} scripts."
    end

    def relative(path)
      Pathname.new(path).relative_path_from(Rails.root).to_s
    rescue ArgumentError
      path.to_s
    end
  end
end
