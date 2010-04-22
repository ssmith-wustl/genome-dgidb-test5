<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  
  <xsl:strip-space elements="*"/>

  <xsl:template match="/">
    <html>
      <head>
        <title>Status <xsl:value-of select="@type"/> <xsl:value-of select="@id" /></title>
        <link rel="shortcut icon" href="/resources/report_resources/apipe_dashboard/images/gc_favicon.png" type="image/png" />
        <link rel="stylesheet" href="/resources/report_resources/apipe_dashboard/css/master.css" type="text/css" media="screen" />
        <link rel="stylesheet" href="/resources/report_resources/apipe_dashboard/css/tablesorter.css" type="text/css" media="screen" />
        <script type="text/javascript" src="/resources/report_resources/jquery/jquery.js"></script>
        <script type="text/javascript" src="/resources/report_resources/jquery/jquery.tablesorter.min.js"></script>
        <!--
            <script type="text/javascript">
            $(document).ready(function() {
            $("#model_list").tablesorter();
            });
            </script>
        -->
      </head>

      <body>
        <div class="container">
          <div class="background">
		    <div class="page_header">
		      <table cellpadding="0" cellspacing="0" border="0">
		        <tr>
		          <td>
		            <a href="status.cgi" alt="Go to Search Page" title="Go to Search Page"><img src="/resources/report_resources/apipe_dashboard/images/gc_header_logo2.png" width="44" height="45" align="absmiddle" /></a>
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
      </body>
    </html>
    
  </xsl:template>

</xsl:stylesheet>
