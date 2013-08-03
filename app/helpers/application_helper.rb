module ApplicationHelper
  def google_analytics
    return unless Rails.env.production?
    %{<script>
      (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
      (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
      m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
      })(window,document,'script','//www.google-analytics.com/analytics.js','ga');
      
      ga('create', 'UA-42907222-1', 'whenharvardmetsally.com');
      ga('send', 'pageview');
    </script>}
  end
  
  def chartbeat_header
    return unless Rails.env.production?
  end
  
  def chartbeat_footer
    return unless Rails.env.production?
  end
end