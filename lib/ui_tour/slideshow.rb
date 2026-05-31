require "json"
require "fileutils"
require "erb"

module UiTour
  # Generates the standalone HTML slideshow from the captured manifest.
  # The output is a single file (index.html) in the same directory as the
  # screenshot PNGs, so it can be opened directly.
  class Slideshow
    def initialize(manifest:, output_dir:, mode:, generated_at:)
      @manifest = manifest
      @output_dir = output_dir
      @mode = mode
      @generated_at = generated_at
    end

    def generate!
      File.write(File.join(@output_dir, "manifest.json"), JSON.pretty_generate(@manifest))
      File.write(File.join(@output_dir, "index.html"), render_html)
    end

    private

    def render_html
      ERB.new(template, trim_mode: "-").result(binding)
    end

    def slides_json
      @manifest.map.with_index(1) do |entry, idx|
        {
          number: idx,
          file: entry["file"],
          script: entry["script_title"],
          scene: entry["scene_name"],
          caption: entry["caption"],
          viewport: entry["viewport"],
          captured_at: entry["captured_at"]
        }
      end.to_json
    end

    def total
      @manifest.size
    end

    def script_titles
      @manifest.map { |e| e["script_title"] }.uniq
    end

    def template
      <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>ugo — UI Tour (<%= @mode %>)</title>
          <link rel="preconnect" href="https://fonts.googleapis.com">
          <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
          <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
          <style>
            :root {
              --bg: #f7f8fa;
              --surface: #ffffff;
              --ink: #0e1320;
              --muted: #5a6478;
              --border: #e3e6ec;
              --accent: #4f46e5;
              --accent-soft: #eef2ff;
              --shadow: 0 1px 2px rgba(15,23,42,.04), 0 8px 24px rgba(15,23,42,.06);
            }
            @media (prefers-color-scheme: dark) {
              :root {
                --bg: #0b0e14;
                --surface: #141926;
                --ink: #eef2f9;
                --muted: #8a93a6;
                --border: #232a3a;
                --accent: #818cf8;
                --accent-soft: #1e2238;
                --shadow: 0 1px 2px rgba(0,0,0,.4), 0 8px 24px rgba(0,0,0,.5);
              }
            }
            * { box-sizing: border-box; }
            html, body { margin: 0; padding: 0; height: 100%; }
            body {
              font-family: "Inter", system-ui, -apple-system, sans-serif;
              background: var(--bg);
              color: var(--ink);
              -webkit-font-smoothing: antialiased;
            }
            .app {
              display: grid;
              grid-template-columns: 280px 1fr;
              height: 100vh;
            }
            aside {
              border-right: 1px solid var(--border);
              background: var(--surface);
              overflow-y: auto;
              padding: 18px 14px;
            }
            aside header {
              padding: 6px 10px 18px;
              border-bottom: 1px solid var(--border);
              margin-bottom: 12px;
            }
            aside header h1 {
              font-size: 14px;
              font-weight: 700;
              letter-spacing: .02em;
              margin: 0 0 4px;
            }
            aside header .meta {
              font-size: 11px;
              color: var(--muted);
              line-height: 1.5;
            }
            .group { margin-bottom: 14px; }
            .group h2 {
              font-size: 11px;
              text-transform: uppercase;
              letter-spacing: .08em;
              color: var(--muted);
              margin: 8px 10px 6px;
            }
            .item {
              display: flex;
              gap: 10px;
              align-items: center;
              width: 100%;
              text-align: left;
              padding: 8px 10px;
              border-radius: 8px;
              border: none;
              background: transparent;
              color: inherit;
              cursor: pointer;
              font: inherit;
              line-height: 1.3;
            }
            .item:hover { background: var(--accent-soft); }
            .item.active { background: var(--accent-soft); }
            .item .num {
              font-variant-numeric: tabular-nums;
              font-size: 11px;
              font-weight: 600;
              color: var(--accent);
              min-width: 28px;
            }
            .item .label { font-size: 13px; }
            .item .vp {
              margin-left: auto;
              font-size: 10px;
              padding: 2px 6px;
              border-radius: 999px;
              background: var(--border);
              color: var(--muted);
            }
            .item .vp.mobile { background: #fde68a; color: #92400e; }
            @media (prefers-color-scheme: dark) {
              .item .vp.mobile { background: #422006; color: #fcd34d; }
            }
            main {
              display: flex;
              flex-direction: column;
              overflow: hidden;
            }
            .topbar {
              display: flex;
              align-items: center;
              gap: 12px;
              padding: 14px 22px;
              border-bottom: 1px solid var(--border);
              background: var(--surface);
            }
            .crumbs {
              font-size: 12px;
              color: var(--muted);
            }
            .crumbs strong { color: var(--ink); font-weight: 600; }
            .counter {
              margin-left: auto;
              font-variant-numeric: tabular-nums;
              font-size: 13px;
              font-weight: 600;
              color: var(--muted);
            }
            .nav-btn {
              border: 1px solid var(--border);
              background: var(--surface);
              padding: 6px 10px;
              border-radius: 8px;
              cursor: pointer;
              font: inherit;
              font-size: 13px;
              color: var(--ink);
            }
            .nav-btn:hover { border-color: var(--accent); color: var(--accent); }
            .nav-btn:disabled { opacity: .35; cursor: not-allowed; }
            .stage {
              flex: 1;
              overflow: auto;
              padding: 24px;
              display: flex;
              flex-direction: column;
              align-items: center;
              gap: 16px;
              background: var(--bg);
            }
            .frame {
              max-width: 100%;
              background: var(--surface);
              border: 1px solid var(--border);
              border-radius: 12px;
              box-shadow: var(--shadow);
              overflow: hidden;
            }
            .frame.mobile { max-width: 420px; }
            .frame img { display: block; width: 100%; height: auto; }
            .caption {
              text-align: center;
              max-width: 700px;
            }
            .caption .scene-name {
              font-size: 18px;
              font-weight: 600;
              margin: 0 0 4px;
            }
            .caption .script-name {
              font-size: 12px;
              color: var(--muted);
              text-transform: uppercase;
              letter-spacing: .08em;
              margin-bottom: 10px;
            }
            .caption .text {
              font-size: 14px;
              color: var(--muted);
              line-height: 1.5;
            }
            kbd {
              font-family: "JetBrains Mono", ui-monospace, monospace;
              font-size: 10px;
              padding: 1px 6px;
              border: 1px solid var(--border);
              border-bottom-width: 2px;
              border-radius: 4px;
              color: var(--muted);
              background: var(--surface);
            }
            .help {
              font-size: 11px;
              color: var(--muted);
              padding: 8px 10px;
              border-top: 1px solid var(--border);
              margin-top: auto;
            }
            .help kbd + kbd { margin-left: 2px; }
          </style>
        </head>
        <body>
          <div class="app">
            <aside>
              <header>
                <h1>UI Tour — <%= @mode %></h1>
                <div class="meta">
                  <%= total %> screenshots · generated <%= @generated_at.strftime("%Y-%m-%d %H:%M") %>
                </div>
              </header>
              <div id="sidebar"></div>
              <div class="help">
                <kbd>←</kbd><kbd>→</kbd> navigate · <kbd>Home</kbd>/<kbd>End</kbd> jump · click any thumbnail
              </div>
            </aside>
            <main>
              <div class="topbar">
                <button class="nav-btn" id="prev">← Prev</button>
                <button class="nav-btn" id="next">Next →</button>
                <div class="crumbs" id="crumbs"></div>
                <div class="counter" id="counter"></div>
              </div>
              <div class="stage">
                <div class="frame" id="frame"><img id="img" alt=""></div>
                <div class="caption">
                  <div class="script-name" id="script-name"></div>
                  <div class="scene-name" id="scene-name"></div>
                  <div class="text" id="caption-text"></div>
                </div>
              </div>
            </main>
          </div>
          <script>
            const SLIDES = <%= slides_json %>;
            const BY_SCRIPT = SLIDES.reduce((acc, s) => {
              (acc[s.script] = acc[s.script] || []).push(s);
              return acc;
            }, {});

            const sidebar = document.getElementById('sidebar');
            for (const [name, items] of Object.entries(BY_SCRIPT)) {
              const group = document.createElement('div');
              group.className = 'group';
              const h = document.createElement('h2');
              h.textContent = name;
              group.appendChild(h);
              for (const slide of items) {
                const btn = document.createElement('button');
                btn.className = 'item';
                btn.dataset.idx = slide.number - 1;
                btn.innerHTML =
                  '<span class="num">' + String(slide.number).padStart(3, '0') + '</span>' +
                  '<span class="label">' + slide.scene + '</span>' +
                  '<span class="vp ' + slide.viewport + '">' + slide.viewport + '</span>';
                btn.addEventListener('click', () => show(slide.number - 1));
                group.appendChild(btn);
              }
              sidebar.appendChild(group);
            }

            const img = document.getElementById('img');
            const frame = document.getElementById('frame');
            const sceneName = document.getElementById('scene-name');
            const scriptName = document.getElementById('script-name');
            const captionText = document.getElementById('caption-text');
            const crumbs = document.getElementById('crumbs');
            const counter = document.getElementById('counter');
            const prevBtn = document.getElementById('prev');
            const nextBtn = document.getElementById('next');

            let cur = 0;
            function show(i) {
              if (i < 0 || i >= SLIDES.length) return;
              cur = i;
              const s = SLIDES[i];
              img.src = 'screenshots/' + s.file;
              img.alt = s.scene;
              sceneName.textContent = s.scene;
              scriptName.textContent = s.script;
              captionText.textContent = s.caption || '';
              crumbs.innerHTML = '<strong>' + s.script + '</strong> · ' + s.scene + ' · <em>' + s.viewport + '</em>';
              counter.textContent = String(s.number).padStart(3, '0') + ' / ' + String(SLIDES.length).padStart(3, '0');
              frame.classList.toggle('mobile', s.viewport === 'mobile');
              prevBtn.disabled = i === 0;
              nextBtn.disabled = i === SLIDES.length - 1;
              document.querySelectorAll('.item').forEach(el => el.classList.toggle('active', Number(el.dataset.idx) === i));
              const active = document.querySelector('.item.active');
              if (active) active.scrollIntoView({block: 'nearest'});
              history.replaceState(null, '', '#' + String(s.number).padStart(3, '0'));
            }
            prevBtn.addEventListener('click', () => show(cur - 1));
            nextBtn.addEventListener('click', () => show(cur + 1));
            document.addEventListener('keydown', e => {
              if (e.key === 'ArrowLeft') show(cur - 1);
              else if (e.key === 'ArrowRight') show(cur + 1);
              else if (e.key === 'Home') show(0);
              else if (e.key === 'End') show(SLIDES.length - 1);
            });

            const initial = Math.max(0, parseInt(location.hash.replace('#', ''), 10) - 1) || 0;
            show(initial);
          </script>
        </body>
        </html>
      HTML
    end
  end
end
