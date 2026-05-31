import { Controller } from "@hotwired/stimulus";

// Shared chart theme colors (matching app's Tailwind config)
const theme = {
  primary: '#5aa9e6',
  primaryLight: '#bcddf2',
  text: '#64748b',
  textDark: '#0f172a',
  border: '#e2e8f0',
  background: '#ffffff'
};

export default class extends Controller {
  static values = { data: Object };

  connect() {
    this.createChart();
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy();
    }
  }

  createChart() {
    const chartData = this.dataValue;

    const options = {
      chart: {
        type: 'area',
        height: '100%',
        fontFamily: 'Inter, ui-sans-serif, system-ui, sans-serif',
        toolbar: { show: false },
        zoom: { enabled: false },
        animations: {
          enabled: true,
          easing: 'easeinout',
          speed: 400
        },
        sparkline: { enabled: false }
      },
      series: [{
        name: 'Visits',
        data: chartData.data
      }],
      colors: [theme.primary],
      fill: {
        type: 'gradient',
        gradient: {
          shadeIntensity: 1,
          type: 'vertical',
          opacityFrom: 0.2,
          opacityTo: 0.05,
          stops: [0, 100],
          colorStops: [
            { offset: 0, color: theme.primary, opacity: 0.2 },
            { offset: 100, color: theme.primary, opacity: 0.05 }
          ]
        }
      },
      stroke: {
        curve: 'smooth',
        width: 2,
        colors: [theme.primary]
      },
      xaxis: {
        categories: chartData.labels,
        labels: {
          style: {
            colors: theme.text,
            fontSize: '11px',
            fontWeight: 500
          },
          rotate: 0,
          hideOverlappingLabels: true
        },
        axisBorder: { show: false },
        axisTicks: { show: false },
        crosshairs: {
          show: true,
          stroke: { color: theme.border, width: 1, dashArray: 3 }
        },
        tooltip: { enabled: false }
      },
      yaxis: {
        labels: {
          style: {
            colors: theme.text,
            fontSize: '11px',
            fontWeight: 500
          },
          formatter: (value) => Number.isInteger(value) ? value : ''
        },
        min: 0,
        forceNiceScale: true
      },
      grid: {
        borderColor: theme.border,
        strokeDashArray: 0,
        xaxis: { lines: { show: false } },
        yaxis: { lines: { show: true } },
        padding: { left: 8, right: 8, top: 16, bottom: 8 }
      },
      markers: {
        size: 0,
        hover: { size: 5, sizeOffset: 2 },
        colors: [theme.background],
        strokeColors: theme.primary,
        strokeWidth: 2
      },
      dataLabels: { enabled: false },
      tooltip: {
        enabled: true,
        shared: true,
        intersect: false,
        theme: 'light',
        style: {
          fontSize: '12px',
          fontFamily: 'Inter, ui-sans-serif, system-ui, sans-serif'
        },
        x: { show: true },
        y: {
          formatter: (value) => value === 1 ? `${value} visit` : `${value} visits`
        },
        marker: { show: true }
      },
      legend: { show: false }
    };

    this.chart = new ApexCharts(this.element, options);
    this.chart.render();
  }
}
