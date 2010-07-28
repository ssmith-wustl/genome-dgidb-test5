<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template name="genome_search_query" match="/solr-results">
    <div class="content rounded shadow" style="padding-top: 0;">
      <xsl:call-template name="app_header">
        <xsl:with-param name="app_name" select="'Analysis Search'"/>
        <xsl:with-param name="icon" select="'app_analysis_search_32'"/>
      </xsl:call-template>

      <div class="container">
        <div class="span-5">
          <br/>
        </div>
        <div class="span-19 last">
          <div class="main_search" style="margin-left: 15px; margin-bottom: 15px;">
            <form action="">
              <table cellpadding="0" cellspacing="0" border="0" class="search_elements">
                <tr>
                  <td>
                    <input class="query_box rounded" type="text" name="query"><xsl:attribute name="value"><xsl:value-of select="//@query"/></xsl:attribute></input>
                  </td>
                  <td>
                    <input type="submit" class="button" value="Search"/>
                  </td>
                </tr>
              </table>
            </form>
            <p class="small" style="margin: 0 0 0 5px;">Found <xsl:value-of select="@num-found"/> records.</p>
          </div>
        </div>

        <div class="span-5">
          <xsl:choose>
            <xsl:when test="/solr-results/@num-found &gt; 0">
              <div class="sidebar_search rounded-right">
                <h4>Show:</h4>
                <ul>

                  <xsl:for-each select="facets/field">
                    <li>
                      <div><xsl:attribute name="class">icon16 <xsl:value-of select="@icon-prefix"/>_16</xsl:attribute><br/></div>
                      <div class="category">
                        <a>
                          <xsl:attribute name="href">
                            /view/genome/search/query/status.html?query=<xsl:value-of select="/solr-results/@query-no-types"/>&amp;fq=type:"<xsl:value-of select="@name"/>"
                          </xsl:attribute>
                          <xsl:value-of select="@label"/>
                        </a>
                      (<xsl:value-of select="@count"/>)</div>
                    </li>

                  </xsl:for-each>
                </ul>
              </div>
            </xsl:when>
            <xsl:otherwise>
              <br/>
            </xsl:otherwise>
          </xsl:choose>
        </div>

        <div class="span-19 last">
          <div style="margin: 0 15px;">

            <xsl:for-each select="result">
              <!-- Pre-generated HTML from a View module -->
              <xsl:value-of disable-output-escaping="yes" select='.'/>
            </xsl:for-each>

            <div class="pager">
              <div class="nav">
                <xsl:choose>
                  <xsl:when test="string(page-info/@previous-page)">
                    <a class="mini btn">
                      <xsl:attribute name="href"><xsl:text>/view/genome/search/query/status.html?query=</xsl:text><xsl:value-of select="@query"/>&amp;fq=type:"<xsl:value-of select="//facets/field/@name"/>"<xsl:text>&amp;page=</xsl:text><xsl:value-of select="page-info/@previous-page" /></xsl:attribute><span class="sm-icon sm-icon-triangle-1-w"><br/></span>
                    </a>
                  </xsl:when>
                  <xsl:otherwise>
                    <a href="#" class="grey mini btn"><span class="sm-icon sm-icon-triangle-1-w"><br/></span></a>
                  </xsl:otherwise>
                </xsl:choose>
              </div>

              <div class="position">Page <xsl:value-of select="page-info/@current-page" /> of <xsl:value-of select="page-info/@last-page" /></div>

              <div class="nav">
                <xsl:choose>
                  <xsl:when test="string(page-info/@next-page)">
                    <a class="mini btn">
                      <xsl:attribute name="href"><xsl:text>/view/genome/search/query/status.html?query=</xsl:text><xsl:value-of select="@query"/>&amp;fq=type:"<xsl:value-of select="//facets/field/@name"/>"<xsl:text>&amp;page=</xsl:text><xsl:value-of select="page-info/@next-page" /></xsl:attribute>
                      <span class="sm-icon sm-icon-triangle-1-e"><br/></span>
                    </a>
                  </xsl:when>
                  <xsl:otherwise>
                    <a href="#" class="grey mini btn"><span class="sm-icon sm-icon-triangle-1-e"><br/></span></a>
                  </xsl:otherwise>
                </xsl:choose>
              </div>
            </div> <!-- end pager -->

          </div>
        </div> <!-- end span-20 -->
      </div> <!-- end container  -->
    </div> <!-- end content  -->

    <xsl:call-template name="footer">
      <xsl:with-param name="footer_text">
        <br/>
      </xsl:with-param>
    </xsl:call-template>

  </xsl:template>

</xsl:stylesheet>
