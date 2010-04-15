<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="html"/>
  <xsl:output doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"/>
  <xsl:output doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"/>

  <xsl:template match="/">

    <html>
      <head>
        <title>Flow Cell <xsl:value-of select="//flow-cell/@id"/></title>

        <link rel="shortcut icon" href="/resources/report_resources/apipe_dashboard/images/gc_favicon.png" type="image/png" />

        <link rel="stylesheet" href="/resources/report_resources/apipe_dashboard/css/master.css" type="text/css" media="screen" />
        <link rel="stylesheet" href="/resources/report_resources/apipe_dashboard/css/tablesorter.css" type="text/css" media="screen" />
        <script type="text/javascript" src="/resources/report_resources/jquery/jquery.js"></script>
        <script type="text/javascript" src="/resources/report_resources/jquery/jquery.tablesorter.min.js"></script>
        <script type="text/javascript">
          $(document).ready(function() {
          $("#lane_list").tablesorter({
          // sort on first column, ascending
          sortList: [[0,0]]
          });
          });
        </script>
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
                    <h1>Analysis Reports v0.1</h1>
                  </td>
                </tr>
              </table>
            </div>

            <div class="page_padding">
              <h2 class="page_title icon_instrument_data">Flow Cell <xsl:value-of select="//flow-cell/@id"/> Status</h2>
              <table cellpadding="0" cellspacing="0" border="0" class="info_table_group">
                <tr>
                  <td>
                    <table border="0" cellpadding="0" cellspacing="0" class="info_table" width="100%">
                      <colgroup>
                        <col/>
                        <col width="100%"/>
                      </colgroup>
                      <tr><td class="label">Flow Cell ID:</td><td class="value"><xsl:value-of select="//flow-cell/@id"/></td></tr>

                      <tr><td class="label">Run Type:</td><td class="value"><xsl:value-of select="//production/@run-type"/></td></tr>
                      <tr><td class="label">Machine:</td><td class="value"><xsl:value-of select="//production/@machine-name"/></td></tr>
                    </table>
                  </td>
                  <td>
                    <table border="0" cellpadding="0" cellspacing="0" class="info_table" width="100%">
                      <colgroup>
                        <col/>
                        <col width="100%"/>
                      </colgroup>
                      <tr><td class="label">Run Name:</td><td class="value"><xsl:value-of select="//production/@run-name"/></td></tr>
                      <tr><td class="label">Date Started:</td><td class="value"><xsl:value-of select="//production/@date-started"/></td></tr>
                      <tr><td class="label">Group:</td><td class="value"><xsl:value-of select="//production/@group-name"/></td></tr>
                    </table>
                  </td>
                </tr>
              </table>
              <hr/>

              <h2>lanes</h2>
              <table id="lane_list" class="list tablesorter" width="100%" cellspacing="0" cellpadding="0" border="0">
                <colgroup>
                  <col />
                  <col />
                </colgroup>
                <thead>
                  <tr>
                    <th>lane</th>
                    <th>id</th>
                    <th>reports</th>
                    <th>resources</th>
                  </tr>
                </thead>
                <tbody>
                  <xsl:choose>
                    <xsl:when test="count(//instrument-data) > 0">
                      <xsl:for-each select="//instrument-data">
                        <xsl:sort select="@lane" data-type="number" order="ascending"/>
                        <xsl:variable name="build-status" select="build_status"/>
                        <tr>
                          <td>
                            <xsl:value-of select="@lane"/>
                          </td>
                          <td><xsl:value-of select="@id"/></td>
                          <td>
                            <xsl:choose>
                              <xsl:when test="report">
                                <xsl:for-each select="report">
                                  <xsl:variable select="@name" name="report_name_full"/>
                                  <a><xsl:attribute name="class">btn_link</xsl:attribute><xsl:attribute name="href">flow_cell_report.cgi?instrument-data-id=<xsl:value-of select="../@id"/>&amp;report-name=<xsl:value-of select="@name"/></xsl:attribute><xsl:value-of select="substring-before($report_name_full,'.')"/></a><xsl:text> </xsl:text>
                                </xsl:for-each>
                              </xsl:when>
                              <xsl:otherwise>
                                <span class="note">No reports available for this lane.</span>
                              </xsl:otherwise>
                            </xsl:choose>
                          </td>
                          <td>
                            <xsl:choose>
                              <xsl:when test="@gerald-directory">
								<a><xsl:attribute name="class">btn_link</xsl:attribute><xsl:attribute name="href">https://gscweb<xsl:value-of select="@gerald-directory"/></xsl:attribute>gerald directory</a>
                              </xsl:when>
                              <xsl:otherwise>
                                <span class="note">No resources found.</span>
                              </xsl:otherwise>
                            </xsl:choose>
                          </td>
                        </tr>
                      </xsl:for-each>
                    </xsl:when>
                    <xsl:otherwise>
                      <tr>
                        <td colspan="5">
                          <strong>No available lanes for this flow cell.</strong>
                        </td>
                      </tr>
                    </xsl:otherwise>
                  </xsl:choose>
                </tbody>
              </table>

            </div>
          </div>
        </div>
      </body>
    </html>

  </xsl:template>

</xsl:stylesheet>
