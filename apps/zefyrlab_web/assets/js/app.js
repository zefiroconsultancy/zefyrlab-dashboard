// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {MagicAuthHooks} from "magic_auth"
import topbar from "../vendor/topbar"
import Chart from "../vendor/chart.umd"

// Chart Hooks - data comes from Elixir LiveView
const ChartHooks = {
  // Section 2: Projection Chart (5-year NAV line)
  ProjectionChart: {
    mounted() {
      const chartData = JSON.parse(this.el.dataset.chart);
      const ctx = this.el.getContext('2d');
      this.resizeCanvas();

      this.chart = new Chart(ctx, {
        type: 'line',
        data: {
          labels: chartData.labels,
          datasets: [{
            label: 'Projected NAV',
            data: chartData.nav,
            borderColor: '#1C7ED6',
            backgroundColor: 'rgba(28, 126, 214, 0.1)',
            fill: true,
            tension: 0.4,
            borderWidth: 2
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          devicePixelRatio: window.devicePixelRatio || 2,
          plugins: {
            legend: { display: false },
            tooltip: {
              mode: 'index',
              intersect: false,
              callbacks: {
                label: (context) => '$' + (context.parsed.y / 1000000).toFixed(1) + 'M'
              }
            }
          },
          scales: {
            y: {
              beginAtZero: false,
              ticks: {
                callback: (value) => '$' + (value / 1000000).toFixed(1) + 'M'
              }
            }
          }
        }
      });
    },
    updated() {
      const chartData = JSON.parse(this.el.dataset.chart);
      this.resizeCanvas();
      this.chart.data.labels = chartData.labels;
      this.chart.data.datasets[0].data = chartData.nav;
      this.chart.update();
    },
    resizeCanvas() {
      const dpr = window.devicePixelRatio || 1;
      const rect = this.el.getBoundingClientRect();
      this.el.width = rect.width * dpr;
      this.el.height = rect.height * dpr;
    }
  },

  // Section 3: Dual Axis Chart (TVL line + Volume bars)
  DualAxisChart: {
    mounted() {
      const chartData = JSON.parse(this.el.dataset.chart);
      const ctx = this.el.getContext('2d');
      this.resizeCanvas();

      this.chart = new Chart(ctx, {
        type: 'bar',
        data: {
          labels: chartData.labels,
          datasets: [
            {
              type: 'bar',
              label: 'Volume',
              data: chartData.volume,
              backgroundColor: 'rgba(28, 126, 214, 0.6)',
              yAxisID: 'y'
            },
            {
              type: 'line',
              label: 'TVL',
              data: chartData.tvl,
              borderColor: '#10B981',
              backgroundColor: 'rgba(16, 185, 129, 0.1)',
              fill: false,
              tension: 0.4,
              yAxisID: 'y1'
            }
          ]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          devicePixelRatio: window.devicePixelRatio || 2,
          interaction: {
            mode: 'index',
            intersect: false
          },
          plugins: {
            legend: { position: 'top' },
            tooltip: {
              callbacks: {
                label: (context) => {
                  const val = context.parsed.y;
                  return context.dataset.label + ': $' + (val / 1000000).toFixed(2) + 'M';
                }
              }
            }
          },
          scales: {
            y: {
              type: 'linear',
              position: 'left',
              title: { display: true, text: 'Volume ($)' },
              ticks: {
                callback: (value) => '$' + (value / 1000000).toFixed(0) + 'M'
              }
            },
            y1: {
              type: 'linear',
              position: 'right',
              title: { display: true, text: 'TVL ($)' },
              grid: { drawOnChartArea: false },
              ticks: {
                callback: (value) => '$' + (value / 1000000).toFixed(0) + 'M'
              }
            }
          }
        }
      });
    },
    updated() {
      const chartData = JSON.parse(this.el.dataset.chart);
      this.resizeCanvas();
      this.chart.data.labels = chartData.labels;
      this.chart.data.datasets[0].data = chartData.volume;
      this.chart.data.datasets[1].data = chartData.tvl;
      this.chart.update();
    },
    resizeCanvas() {
      const dpr = window.devicePixelRatio || 1;
      const rect = this.el.getBoundingClientRect();
      this.el.width = rect.width * dpr;
      this.el.height = rect.height * dpr;
    }
  },

  // Section 4: Stacked Area Chart (Wallet + Bonded + Cashflow line)
  StackedAreaChart: {
    mounted() {
      const chartData = JSON.parse(this.el.dataset.chart);
      const ctx = this.el.getContext('2d');
      this.resizeCanvas();

      this.chart = new Chart(ctx, {
        type: 'line',
        data: {
          labels: chartData.labels,
          datasets: [
            {
              label: 'Wallet',
              data: chartData.wallet,
              backgroundColor: 'rgba(28, 126, 214, 0.5)',
              borderColor: '#1C7ED6',
              fill: true,
              tension: 0.4
            },
            {
              label: 'Bonded',
              data: chartData.bonded,
              backgroundColor: 'rgba(16, 185, 129, 0.5)',
              borderColor: '#10B981',
              fill: true,
              tension: 0.4
            },
            {
              type: 'line',
              label: 'Net Cashflow',
              data: chartData.net_cashflow,
              borderColor: '#F59E0B',
              backgroundColor: 'transparent',
              borderWidth: 2,
              fill: false,
              tension: 0.4,
              pointRadius: 0
            }
          ]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          devicePixelRatio: window.devicePixelRatio || 2,
          interaction: {
            mode: 'index',
            intersect: false
          },
          plugins: {
            legend: { position: 'top' },
            tooltip: {
              callbacks: {
                label: (context) => {
                  const val = context.parsed.y;
                  if (context.datasetIndex === 2) {
                    return context.dataset.label + ': $' + val.toLocaleString();
                  }
                  return context.dataset.label + ': ' + val.toLocaleString();
                }
              }
            }
          },
          scales: {
            y: {
              stacked: true,
              beginAtZero: true,
              ticks: {
                callback: (value) => {
                  if (value >= 1000000) return '$' + (value / 1000000).toFixed(1) + 'M';
                  if (value >= 1000) return '$' + (value / 1000).toFixed(0) + 'K';
                  return '$' + value;
                }
              }
            }
          }
        }
      });
    },
    updated() {
      const chartData = JSON.parse(this.el.dataset.chart);
      this.resizeCanvas();
      this.chart.data.labels = chartData.labels;
      this.chart.data.datasets[0].data = chartData.wallet;
      this.chart.data.datasets[1].data = chartData.bonded;
      this.chart.data.datasets[2].data = chartData.net_cashflow;
      this.chart.update();
    },
    resizeCanvas() {
      const dpr = window.devicePixelRatio || 1;
      const rect = this.el.getBoundingClientRect();
      this.el.width = rect.width * dpr;
      this.el.height = rect.height * dpr;
    }
  },

  // Section 5: Rewards vs Bonded Chart (bars + line + secondary axis)
  RewardsBondedChart: {
    mounted() {
      const chartData = JSON.parse(this.el.dataset.chart);
      const ctx = this.el.getContext('2d');
      this.resizeCanvas();

      this.chart = new Chart(ctx, {
        type: 'bar',
        data: {
          labels: chartData.labels,
          datasets: [
            {
              type: 'bar',
              label: 'Rewards (RUNE)',
              data: chartData.rewards,
              backgroundColor: 'rgba(28, 126, 214, 0.6)',
              yAxisID: 'y'
            },
            {
              type: 'line',
              label: 'Bonded Capital (RUNE)',
              data: chartData.bonded,
              borderColor: '#10B981',
              backgroundColor: 'rgba(16, 185, 129, 0.1)',
              fill: false,
              tension: 0.4,
              yAxisID: 'y'
            },
            {
              type: 'line',
              label: 'Daily Return %',
              data: chartData.daily_return_pct,
              borderColor: '#F59E0B',
              backgroundColor: 'transparent',
              borderWidth: 2,
              fill: false,
              tension: 0.4,
              yAxisID: 'y1',
              pointRadius: 0
            }
          ]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          devicePixelRatio: window.devicePixelRatio || 2,
          interaction: {
            mode: 'index',
            intersect: false
          },
          plugins: {
            legend: { position: 'top' },
            tooltip: {
              callbacks: {
                label: (context) => {
                  const val = context.parsed.y;
                  if (context.datasetIndex === 2) {
                    return context.dataset.label + ': ' + val.toFixed(2) + '%';
                  }
                  return context.dataset.label + ': ' + val.toLocaleString();
                }
              }
            }
          },
          scales: {
            y: {
              type: 'linear',
              position: 'left',
              title: { display: true, text: 'RUNE' },
              ticks: {
                callback: (value) => value.toLocaleString()
              }
            },
            y1: {
              type: 'linear',
              position: 'right',
              title: { display: true, text: 'Daily Return %' },
              grid: { drawOnChartArea: false },
              ticks: {
                callback: (value) => value.toFixed(2) + '%'
              }
            }
          }
        }
      });
    },
    updated() {
      const chartData = JSON.parse(this.el.dataset.chart);
      this.resizeCanvas();
      this.chart.data.labels = chartData.labels;
      this.chart.data.datasets[0].data = chartData.rewards;
      this.chart.data.datasets[1].data = chartData.bonded;
      this.chart.data.datasets[2].data = chartData.daily_return_pct;
      this.chart.update();
    },
    resizeCanvas() {
      const dpr = window.devicePixelRatio || 1;
      const rect = this.el.getBoundingClientRect();
      this.el.width = rect.width * dpr;
      this.el.height = rect.height * dpr;
    }
  },

  // Section 6: Stacked Bar Chart (Capital + Rewards + Costs + Net line)
  StackedBarChart: {
    mounted() {
      const chartData = JSON.parse(this.el.dataset.chart);
      const ctx = this.el.getContext('2d');
      this.resizeCanvas();

      this.chart = new Chart(ctx, {
        type: 'bar',
        data: {
          labels: chartData.labels,
          datasets: [
            {
              label: 'Capital In',
              data: chartData.capital_in,
              backgroundColor: 'rgba(59, 130, 246, 0.6)',
              stack: 'flows'
            },
            {
              label: 'Rewards',
              data: chartData.rewards,
              backgroundColor: 'rgba(16, 185, 129, 0.6)',
              stack: 'flows'
            },
            {
              label: 'Costs',
              data: chartData.costs,
              backgroundColor: 'rgba(239, 68, 68, 0.6)',
              stack: 'flows'
            },
            {
              type: 'line',
              label: 'Net Cashflow',
              data: chartData.net_cashflow,
              borderColor: '#F59E0B',
              backgroundColor: 'transparent',
              borderWidth: 2,
              fill: false,
              tension: 0.4
            }
          ]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          devicePixelRatio: window.devicePixelRatio || 2,
          interaction: {
            mode: 'index',
            intersect: false
          },
          plugins: {
            legend: { position: 'top' },
            tooltip: {
              callbacks: {
                label: (context) => {
                  const val = context.parsed.y;
                  return context.dataset.label + ': $' + val.toLocaleString();
                }
              }
            }
          },
          scales: {
            y: {
              stacked: true,
              ticks: {
                callback: (value) => {
                  if (value >= 1000000) return '$' + (value / 1000000).toFixed(1) + 'M';
                  if (value >= 1000) return '$' + (value / 1000).toFixed(0) + 'K';
                  return '$' + value;
                }
              }
            }
          }
        }
      });
    },
    updated() {
      const chartData = JSON.parse(this.el.dataset.chart);
      this.resizeCanvas();
      this.chart.data.labels = chartData.labels;
      this.chart.data.datasets[0].data = chartData.capital_in;
      this.chart.data.datasets[1].data = chartData.rewards;
      this.chart.data.datasets[2].data = chartData.costs;
      this.chart.data.datasets[3].data = chartData.net_cashflow;
      this.chart.update();
    },
    resizeCanvas() {
      const dpr = window.devicePixelRatio || 1;
      const rect = this.el.getBoundingClientRect();
      this.el.width = rect.width * dpr;
      this.el.height = rect.height * dpr;
    }
  }
};

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...MagicAuthHooks, ...ChartHooks}
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
