<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  
  <xsl:strip-space elements="*"/>

  <xsl:template match="/">
  <xsl:variable name="title">
    <xsl:choose>
      <xsl:when test="/object">
        <xsl:value-of select="/object/label_name" />: <xsl:value-of select="/object/display_name" /> - Status
      </xsl:when>
      <xsl:otherwise>
        Status
      </xsl:otherwise>  
    </xsl:choose>
  </xsl:variable>
    <html>
      <head>
        <title><xsl:value-of select="normalize-space($title)"/></title>
        <link rel="shortcut icon" href="/res/img/gc_favicon.png" type="image/png" />
        <link rel="stylesheet" href="/res/css/master.css" type="text/css" media="screen" />
        <link rel="stylesheet" href="/res/old/report_resources/apipe_dashboard/css/tablesorter.css" type="text/css" media="screen" />
        <script type="text/javascript" src="/res/js/jquery.js"></script>
        <script type="text/javascript" src="/res/old/report_resources/jquery/jquery.tablesorter.min.js"></script>
        <script type="text/javascript">
          <![CDATA[
            (function($) {
              var cache = [];
              // Arguments are image paths relative to the current page.
              $.preLoadImages = function() {
                var args_len = arguments.length;
                for (var i = args_len; i--;) {
                  var cacheImage = document.createElement('img');
                  cacheImage.src = arguments[i];
                  cache.push(cacheImage);
                }
              }
            })(jQuery)

            $(document).ready(function() {
                $.preLoadImages("/res/img/spinner.gif");

                $("#ajax_status")
                .addClass('success')
                .bind("ajaxSend", function(){
                    $(this).removeClass('success error').addClass('loading').html('Loading').show();
                })
                .bind("ajaxSuccess", function(){
                    $(this).removeClass('loading').addClass('success').html('Success').hide('slow');
                })
                .bind("ajaxError", function(){
                    $(this).removeClass('loading').addClass('error').html('Error');
                })
                .hide();
            });
          ]]>
        </script>
        <script language="javascript" type="text/javascript">
          <![CDATA[
                   $(document).ready(function(){

//Hide (Collapse) the toggle containers on load
$(".toggle_container").hide();

//Slide up and down on click
$("span.trigger").click(function(){
console.log("this: " + $(this));
$(this).parent().next(".toggle_container").slideToggle("slow");
});

});
          ]]>
        </script>
      </head>

      <body>
        <div class="container">
          <div class="background">
		    <div class="page_header">
		      <table cellpadding="0" cellspacing="0" border="0">
		        <tr>
		          <td>
		            <a href="/view/genome/search/status.html" alt="Go to Search Page" title="Go to Search Page"><img src="/res/old/report_resources/apipe_dashboard/images/gc_header_logo2.png" width="44" height="45" align="absmiddle" /></a>
		          </td>
		          <td>
		            <h1>Analysis Reports v0.2</h1>
		          </td>
		        </tr>
		      </table>
		    </div>
		    <div class="page_padding">
              <xsl:apply-templates/>
            </div>
          </div>
        </div>
        <div id="ajax_status"/>
      </body>
    </html>
    
  </xsl:template>

</xsl:stylesheet>
