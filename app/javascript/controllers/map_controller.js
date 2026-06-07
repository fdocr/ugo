import { Controller } from "@hotwired/stimulus";

// Shared chart theme colors (matching app's Tailwind config)
const theme = {
  primary: '#5aa9e6',
  primaryLight: '#e8f4fc',
  primaryDark: '#3b82a0',
  hover: '#2d6a8a',
  text: '#64748b',
  textDark: '#0f172a',
  border: '#e2e8f0',
  background: '#ffffff',
  muted: '#f1f5f9'
};

export default class extends Controller {
  static values = { data: Object };

  connect() {
    this.createMap();
  }

  disconnect() {
    if (this.resizeHandler) {
      window.removeEventListener("resize", this.resizeHandler);
      this.resizeHandler = null;
    }

    clearTimeout(this.resizeTimeout);
    this.element.innerHTML = '';
    this.map = null;
  }

  createMap() {
    const mapData = this.dataValue;

    // If no data, show empty state
    if (!mapData.data || Object.keys(mapData.data).length === 0) {
      this.element.innerHTML = `
        <div class="flex flex-col items-center justify-center h-full text-center">
          <svg class="w-12 h-12 text-gray-300 mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <p class="text-sm text-gray-400">No geographic data available</p>
        </div>
      `;
      return;
    }

    const maxValue = mapData.max || 1;
    const countryNames = mapData.names || {};

    const fills = {
      defaultFill: theme.muted,
      low: theme.primaryLight,
      medium: theme.primary,
      high: theme.primaryDark
    };

    const data = {};
    Object.entries(mapData.data).forEach(([code, value]) => {
      let fillKey;
      const ratio = value / maxValue;
      if (ratio > 0.66) {
        fillKey = 'high';
      } else if (ratio > 0.33) {
        fillKey = 'medium';
      } else {
        fillKey = 'low';
      }

      data[code] = {
        fillKey: fillKey,
        visits: value,
        name: countryNames[code] || code
      };
    });

    this.map = new Datamap({
      element: this.element,
      // Fixed-height chart slot (h-64). responsive:true adds a padding-bottom
      // aspect-ratio hack that fights the slot and breaks tooltip positioning.
      responsive: false,
      projection: 'mercator',
      fills: fills,
      data: data,
      geographyConfig: {
        borderColor: theme.border,
        borderWidth: 0.5,
        // Hover is fully self-managed in setupHover. DataMaps' built-in hover
        // re-appends the hovered <path> to the DOM (moveToFront), which races
        // with mouseout in Chromium and leaves countries stuck highlighted
        // (see issue #17). Disabling both stops DataMaps from binding any
        // subunit handlers so no DOM reordering happens.
        highlightOnHover: false,
        popupOnHover: false,
        popupTemplate: (geography, data) => {
          const name = data?.name || geography.properties.name;
          const visits = data?.visits || 0;
          const visitText = visits === 1 ? 'visit' : 'visits';

          return `
            <div class="hoverinfo" style="
              font-family: Inter, ui-sans-serif, system-ui, sans-serif;
              font-size: 12px;
              padding: 8px 12px;
              background: ${theme.background};
              border: 1px solid ${theme.border};
              border-radius: 6px;
              box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            ">
              <div style="font-weight: 600; color: ${theme.textDark}; margin-bottom: 2px;">${name}</div>
              <div style="color: ${theme.text};">${visits > 0 ? `${visits} ${visitText}` : 'No visits'}</div>
            </div>
          `;
        }
      },
      done: (datamap) => {
        this.setupHover(datamap, fills);
        this.setupResize();
      }
    });
  }

  // Self-managed hover using mouseenter/mousemove/mouseleave. These fire
  // reliably per country (unlike DataMaps' mouseover/mouseout, which it breaks
  // by reordering the DOM on hover). Highlight is applied on enter and always
  // restored on leave, with an svg-level safety net for fast exits.
  setupHover(datamap, fills) {
    const d3 = window.d3;
    if (!d3) return;

    const element = datamap.options.element;
    const data = datamap.options.data;
    const subunits = datamap.svg.selectAll(".datamaps-subunit");
    const popupTemplate = datamap.options.geographyConfig.popupTemplate;

    let tooltip = d3.select(element).select(".datamaps-hoverover");
    if (tooltip.empty()) {
      tooltip = d3.select(element).append("div")
        .attr("class", "datamaps-hoverover")
        .style("display", "none")
        .style("position", "absolute")
        .style("pointer-events", "none")
        .style("z-index", "10001");
    }

    const baseFill = (geography) => {
      const country = data[geography.id];
      return country?.fillKey ? fills[country.fillKey] : fills.defaultFill;
    };

    const restore = function (geography) {
      d3.select(this)
        .style("fill", baseFill(geography))
        .style("stroke", theme.border)
        .style("stroke-width", "0.5px");
    };

    subunits
      .on("mouseenter", function () {
        d3.select(this)
          .style("fill", theme.hover)
          .style("stroke", theme.textDark)
          .style("stroke-width", "1px");
      })
      .on("mousemove", function (geography) {
        const mouse = d3.mouse(element);
        tooltip
          .style("display", "block")
          .style("left", `${mouse[0]}px`)
          .style("top", `${mouse[1] + 30}px`)
          .html(popupTemplate(geography, data[geography.id]));
      })
      .on("mouseleave", function (geography) {
        restore.call(this, geography);
        tooltip.style("display", "none");
      });

    // Safety net: if the pointer leaves the map fast enough to skip a
    // country's mouseleave, clear every highlight and hide the tooltip.
    datamap.svg.on("mouseleave", () => {
      subunits.each(function (geography) {
        restore.call(this, geography);
      });
      tooltip.style("display", "none");
    });
  }

  // responsive:false fixes the SVG to its pixel size at creation, so a viewport
  // change won't reflow it. Rebuild (debounced) to refit the slot width.
  setupResize() {
    this.resizeHandler = () => {
      if (!this.map) return;
      clearTimeout(this.resizeTimeout);
      this.resizeTimeout = setTimeout(() => this.recreateMap(), 150);
    };
    window.addEventListener("resize", this.resizeHandler);
  }

  recreateMap() {
    if (this.resizeHandler) {
      window.removeEventListener("resize", this.resizeHandler);
      this.resizeHandler = null;
    }

    clearTimeout(this.resizeTimeout);
    this.element.innerHTML = '';
    this.map = null;
    this.createMap();
  }
}
