import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { data: Object };

  connect() {
    this.allData = this.dataValue;
    this.currentFilter = "device_type";
    this.render();
  }

  disconnect() {
    this.element.innerHTML = '';
  }

  updateChart(filterType) {
    if (this.allData[filterType]) {
      this.currentFilter = filterType;
      this.render();
    }
  }

  render() {
    const chartData = this.allData[this.currentFilter];
    
    if (!chartData || !chartData.labels || chartData.labels.length === 0) {
      this.element.innerHTML = `
        <div class="flex flex-col items-center justify-center h-full text-center">
          <svg class="w-12 h-12 text-gray-300 mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
          </svg>
          <p class="text-sm text-gray-400">No device data available</p>
        </div>
      `;
      return;
    }

    const maxValue = Math.max(...chartData.data);
    const total = chartData.data.reduce((a, b) => a + b, 0);

    // Build rows
    const rows = chartData.labels.map((label, index) => {
      const value = chartData.data[index];
      const percentage = maxValue > 0 ? (value / maxValue) * 100 : 0;
      const percentOfTotal = total > 0 ? ((value / total) * 100).toFixed(1) : 0;
      
      return `
        <div class="group relative flex items-center h-9 rounded-md overflow-hidden hover:bg-slate-50 transition-colors">
          <!-- Background bar -->
          <div 
            class="absolute inset-y-0 left-0 bg-primary-100 rounded-md transition-all duration-300"
            style="width: ${percentage}%">
          </div>
          <!-- Content -->
          <div class="relative flex items-center justify-between w-full px-3">
            <span class="text-sm font-medium text-slate-700 truncate pr-4">${this.escapeHtml(label)}</span>
            <div class="flex items-center gap-2 shrink-0">
              <span class="text-sm font-semibold text-slate-900">${value}</span>
              <span class="text-xs text-slate-500 w-12 text-right">${percentOfTotal}%</span>
            </div>
          </div>
        </div>
      `;
    }).join('');

    this.element.innerHTML = `
      <div class="h-full overflow-y-auto pr-1 space-y-1">
        ${rows}
      </div>
    `;
  }

  escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }
}
