// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {MagicAuthHooks} from "magic_auth"
import topbar from "../vendor/topbar"

// Chart Hooks - data comes from Elixir LiveView
const ChartHooks = {
  BondedChart: {
    mounted() {
      const chartData = JSON.parse(this.el.dataset.chart);
      const ctx = this.el.getContext('2d');

      this.chart = new Chart(ctx, {
        type: 'line',
        data: {
          labels: chartData.labels,
          datasets: [{
            label: 'Bonded Capital (RUNE)',
            data: chartData.data,
            borderColor: '#1C7ED6',
            backgroundColor: 'rgba(28, 126, 214, 0.1)',
            fill: true,
            tension: 0.4
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          devicePixelRatio: window.devicePixelRatio || 2,
          plugins: {
            legend: {
              display: false
            },
            tooltip: {
              mode: 'index',
              intersect: false
            }
          },
          interaction: {
            mode: 'nearest',
            axis: 'x',
            intersect: false
          },
          scales: {
            y: {
              beginAtZero: false,
              ticks: {
                callback: function(value) {
                  return (value / 1000000).toFixed(1) + 'M';
                }
              }
            }
          }
        }
      });
    },
    updated() {
      const chartData = JSON.parse(this.el.dataset.chart);
      this.chart.data.labels = chartData.labels;
      this.chart.data.datasets[0].data = chartData.data;
      this.chart.update();
    }
  },

  RewardsChart: {
    mounted() {
      const chartData = JSON.parse(this.el.dataset.chart);
      const ctx = this.el.getContext('2d');

      this.chart = new Chart(ctx, {
        type: 'bar',
        data: {
          labels: chartData.labels,
          datasets: [
            {
              label: 'Actual Rewards',
              data: chartData.actual,
              backgroundColor: '#1C7ED6'
            },
            {
              label: 'Projected Rewards',
              data: chartData.projected,
              backgroundColor: '#E5E7EB'
            }
          ]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          devicePixelRatio: window.devicePixelRatio || 2,
          plugins: {
            legend: {
              position: 'top',
            },
            tooltip: {
              mode: 'index',
              intersect: false
            }
          },
          interaction: {
            mode: 'nearest',
            axis: 'x',
            intersect: false
          },
          scales: {
            y: {
              beginAtZero: true,
              ticks: {
                callback: function(value) {
                  return '$' + (value / 1000).toFixed(0) + 'k';
                }
              }
            }
          }
        }
      });
    },
    updated() {
      const chartData = JSON.parse(this.el.dataset.chart);
      this.chart.data.labels = chartData.labels;
      this.chart.data.datasets[0].data = chartData.actual;
      this.chart.data.datasets[1].data = chartData.projected;
      this.chart.update();
    }
  },

  IncomeChart: {
    mounted() {
      const chartData = JSON.parse(this.el.dataset.chart);
      const ctx = this.el.getContext('2d');

      this.chart = new Chart(ctx, {
        type: 'line',
        data: {
          labels: chartData.labels,
          datasets: [{
            label: 'Cumulative Net Income',
            data: chartData.data,
            borderColor: '#10B981',
            backgroundColor: 'rgba(16, 185, 129, 0.1)',
            fill: true,
            tension: 0.4
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          devicePixelRatio: window.devicePixelRatio || 2,
          plugins: {
            legend: {
              display: false
            },
            tooltip: {
              mode: 'index',
              intersect: false
            }
          },
          interaction: {
            mode: 'nearest',
            axis: 'x',
            intersect: false
          },
          scales: {
            y: {
              beginAtZero: true,
              ticks: {
                callback: function(value) {
                  return '$' + (value / 1000).toFixed(0) + 'k';
                }
              }
            }
          }
        }
      });
    },
    updated() {
      const chartData = JSON.parse(this.el.dataset.chart);
      this.chart.data.labels = chartData.labels;
      this.chart.data.datasets[0].data = chartData.data;
      this.chart.update();
    }
  },

  CostsChart: {
    mounted() {
      const chartData = JSON.parse(this.el.dataset.chart);
      const ctx = this.el.getContext('2d');

      this.chart = new Chart(ctx, {
        type: 'bar',
        data: {
          labels: chartData.labels,
          datasets: [{
            label: 'Costs',
            data: chartData.data,
            backgroundColor: '#EF4444'
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          devicePixelRatio: window.devicePixelRatio || 2,
          plugins: {
            legend: {
              display: false
            },
            tooltip: {
              mode: 'index',
              intersect: false
            }
          },
          interaction: {
            mode: 'nearest',
            axis: 'x',
            intersect: false
          },
          scales: {
            y: {
              beginAtZero: true,
              ticks: {
                callback: function(value) {
                  return '$' + (value / 1000).toFixed(0) + 'k';
                }
              }
            }
          }
        }
      });
    },
    updated() {
      const chartData = JSON.parse(this.el.dataset.chart);
      this.chart.data.labels = chartData.labels;
      this.chart.data.datasets[0].data = chartData.data;
      this.chart.update();
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
