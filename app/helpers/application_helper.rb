module ApplicationHelper
  def google_analytics
    return unless Rails.env.production?
    %{
      <script>
        (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
        (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
        m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
        })(window,document,'script','//www.google-analytics.com/analytics.js','ga');

        ga('create', 'UA-43086484-1', 'weddingcrunchers.com');
        ga('send', 'pageview');

      </script>
    }
  end
  
  def chartbeat_header
    return unless Rails.env.production?
    %{<script type="text/javascript">var _sf_startpt=(new Date()).getTime()</script>}
  end
  
  def chartbeat_footer
    return unless Rails.env.production?
    %{
      <script type="text/javascript">
        var _sf_async_config = { uid: 32398, domain: 'weddingcrunchers.com', useCanonical: true };
        (function() {
          function loadChartbeat() {
            window._sf_endpt = (new Date()).getTime();
            var e = document.createElement('script');
            e.setAttribute('language', 'javascript');
            e.setAttribute('type', 'text/javascript');
            e.setAttribute('src','//static.chartbeat.com/js/chartbeat.js');
            document.body.appendChild(e);
          };
          var oldonload = window.onload;
          window.onload = (typeof window.onload != 'function') ?
            loadChartbeat : function() { oldonload(); loadChartbeat(); };
        })();
      </script>
    }
  end
  
  def name_of_site
    "Wedding Crunchers"
  end
  
  def writeup_url
    ENV['WRITEUP_URL'].presence || "http://rapgenius.com/"
  end
end