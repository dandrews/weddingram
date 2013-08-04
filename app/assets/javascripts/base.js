$(function() {
  var getKeys = function(obj) {
    var key, keys;
    keys = [];
    for (key in obj) {
      keys.push(key);
    }
    return keys;
  };
  
  if ($('#q').val()) {
    $('#ngramSubmit').submit();
  }
  
  $('#ngramForm').on({
    'ajax:error': function() {
      alert("WHOOPS! Something went wrong, try again")
    },
    'submit': function() {
      $("#articleSummaries").empty()
    },
    'ajax:success': function(xhr, data, status) {
      var $this, query, filename;
      $this = $(this);
      
      if (data["tagline"]) {
        $("#tagline").html(data["tagline"]);
      }
      
      query = $this.find('#q').val();
      smooth = $this.find('#s').val();
      filename = 'Weddingram_' + query.replace(RegExp(/[^A-Za-z0-9]/g), '').substr(0, 20);
      
      var series, term, terms, _i, _len;
      if (data["error"]) {
        alert(data["error"]);
        return false;
      } else if (!data) {
        alert("Something went wrong, try again");
        return false;
      }
      
      if (history.pushState) {
        window.history.pushState(null, null, "/?q=" + query + "&s=" + smooth);
      }
      
      terms = getKeys(data["terms"]);
      series = [];
      for (_i = 0, _len = terms.length; _i < _len; _i++) {
        term = terms[_i];
        series.push({
          name: term,
          data: data["terms"][term],
          pointStart: data["years"][0]
        });
      }
      
      $('#ngramContainer').highcharts({
        tooltip: {
          enabled: true,
          shared: true,
          formatter: function() {
            var s = '<b>' + this.x + '</b>'
            $.each(this.points, function(i, point) {
              s += '<br/><span style="color: ' + point["series"]["color"] + '">' +
                    point.series.name + ':</span> ' +
                    Math.round(100 * point.y * 1000000) / 1000000 + '%'
            });
            return s;
          }
        },
        xAxis: {
          categories: data["years"],
          tickInterval: 5,
          tickWidth: 0,
          gridLineWidth: 1,
          tickmarkPlacement: 'on'
        },
        yAxis: {
          min: 0,
          plotLines: [
            {
              value: 0,
              width: 1,
              color: '#808080'
            }
          ],
          labels: {
            formatter: function() {
              return Math.round(100 * 1000000000000 * this.value) / 1000000000000 + "%";
            }
          },
          title: {
            text: ""
          }
        },
        title: {
          text: terms.join(", "),
          style: {
            fontSize: '18px',
            lineHeight: '18px'
          },
          margin: 15
        },
        subtitle: {
          text: "Smoothing Factor " + data["smoothing"]
        },
        series: series,
        legend: {
          layout: "horizontal",
          align: "center",
          verticalAlign: "bottom",
          borderWidth: 0,
          itemStyle: {
            fontSize: '14px'
          }
        },
        plotOptions: {
          series: {
            animation: false,
            marker: {
              enabled: false
            }
          }
        },
        exporting: {
          filename: filename,
          buttons: {
            contextButton: {
              symbol: false,
              text: 'Save as PNG',
              onclick: function() {
                this.exportChart();
              }
            }
          }
        }
      });
      
      $.get("/articles/search", { q: query }, function(data) {
        $("#articleSummaries").html(data)
      });
    }
  });
});