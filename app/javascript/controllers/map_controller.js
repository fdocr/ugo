import { Controller } from "@hotwired/stimulus";

// Shared chart theme colors (matching app's Tailwind config)
const theme = {
  primary: '#5aa9e6',
  primaryLight: '#e8f4fc',
  primaryDark: '#3b82a0',
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
    // Clean up DataMaps SVG
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

    // Build fills object for DataMaps
    const fills = {
      defaultFill: theme.muted,
      low: theme.primaryLight,
      medium: theme.primary,
      high: theme.primaryDark
    };

    // Build data object with fillKey based on value
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

    // Create DataMaps instance
    this.map = new Datamap({
      element: this.element,
      responsive: true,
      projection: 'mercator',
      fills: fills,
      data: data,
      geographyConfig: {
        borderColor: theme.border,
        borderWidth: 0.5,
        highlightOnHover: true,
        highlightFillColor: theme.primary,
        highlightBorderColor: theme.textDark,
        highlightBorderWidth: 1,
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
        // Handle window resize
        window.addEventListener('resize', () => {
          datamap.resize();
        });
      }
    });
  }
}
