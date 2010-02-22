<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
                xmlns:set="http://exslt.org/sets">

  <xsl:output method="html"/>
  <xsl:output encoding="utf-8"/>
  <xsl:output doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"/>
  <xsl:output doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"/>

  <xsl:template match="/">

    <html>
      <head>
        <title>Summary: <xsl:value-of select="//model-info/name"/>&#160;<xsl:value-of select="//model-info/id"/></title>
        <link rel="shortcut icon" href="https://lims.gsc.wustl.edu/resources/report_resources/apipe_dashboard/images/gc_favicon.png" type="image/png" />
        <link rel="stylesheet" href="https://lims.gsc.wustl.edu/resources/report_resources/apipe_dashboard/css/master.css" type="text/css" media="screen" />
        <script type="text/javascript" src="https://lims.gsc.wustl.edu/resources/report_resources/jquery/jquery.js"></script>
        
        <!-- initialize data tables -->
        <!-- note: dataTables doesn't like to be applied to a table with no column headers (which will happen if we create a 'None found' table), so must be applied using $(document).ready on a per-table basis in the body of the page. -->
        <script type="text/javascript" src="https://lims.gsc.wustl.edu/resources/report_resources/jquery/dataTables-1.5/media/js/jquery.dataTables.js"></script>
        <script type="text/javascript" src="https://lims.gsc.wustl.edu/resources/report_resources/jquery/dataTables-1.5/media/js/jquery.dataTables.plugin.formatted-num.js"></script>
        <link rel="stylesheet" href="https://lims.gsc.wustl.edu/resources/report_resources/jquery/dataTables-1.5/media/css/gc_table.css" type="text/css" media="screen"></link>
      </head>

      <body>
        <div class="container">
          <div class="background">
            <div class="page_header">
              <table cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td>
                    <img src="https://lims.gsc.wustl.edu/resources/report_resources/apipe_dashboard/images/gc_header_logo2.png" width="44" height="45" align="absmiddle" />
                  </td>
                  <td>
                    <h1><xsl:value-of select="//model-info/name"/>&#160;<xsl:value-of select="//model-info/id"/>&#160;Summary</h1>
                  </td>
                </tr>
              </table>
            </div>
            <div class="page_padding">
              <h2 class="report_section" style="margin-bottom: 0">Models</h2>
              <table id="models" class="list display" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin-top: 0;">
                    <thead>
                      <tr>
                        <th>id</th>
                        <th>name</th>
                      </tr>
                    </thead>
                    <tbody>
                      <xsl:for-each select="//members/member">
                        <tr>
                          <td>
                            <xsl:value-of select="@id"/>
                          </td>
                          <td>
                            <xsl:value-of select="@name"/>
                          </td>
                        </tr>
                      </xsl:for-each>
                    </tbody>
              </table>
              <xsl:if test="count(//members/member) > 0">
                <script type="text/javascript" charset="utf-8">
                  $(document).ready( function() {
                      $('#models').dataTable( {
						  "bAutoWidth": false,
						  "bStateSave": true,
						  "aoColumns": [
							  null,
							  null
						  ]
					  } );
                  } );
                </script>
              </xsl:if>

              <br clear="all"/>
            </div>
          </div>
        </div>
      </body>
    </html>

  </xsl:template>

</xsl:stylesheet>
