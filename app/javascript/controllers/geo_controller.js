import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { data: Object };

  connect() {
    this.allData = this.dataValue;
    this.currentFilter = "country";
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
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <p class="text-sm text-gray-400">No geographic data available</p>
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
