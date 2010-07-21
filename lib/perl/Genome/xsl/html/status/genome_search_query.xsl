<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template name="genome_search_query" match="/solr-results">

    <script type="text/javascript">
      (function($) {
        $("div.page_padding").css("padding","0px");
        $("div.background,div.container").width(960);
        $('head').append('<link rel="stylesheet" href="/res/css/search.css" type="text/css" />');
      })(jQuery);
    </script>
    <div class="search_form_container">
      <div class="search_form">
        <form method="get">
          <table cellspacing="0" cellpadding="0" border="0" class="form">
            <tr>
              <td>
                <input type="text" size="30" style="background-color: #FFF; font-size: 120%
;"><xsl:attribute name="name">query</xsl:attribute><xsl:attribute 
name="value"><xsl:value-of select="//@query"/></xsl:attribute></input><br/>
              </td>
              <td>
                <input type="submit" value="Search"/>
              </td>
            </tr>
          </table>
        </form>
      </div>
      <div class="search_help">
        <table border="0" cellpadding="0" cellspacing="0" class="search_filter">
          <tr>
            <td colspan="8" class="title">
              <p>Show:</p>
            </td>
          </tr>
          <tr>
            <!-- view all -->
            <td class="icon"><a><xsl:attribute name="href"><xsl:text>?query=</xsl:text><xsl:value-of select="//@query-no-types"/></xsl:attribute><img src="/res/old/report_resources/apipe_dashboard/images/icons/eye_16.png" /></a></td>
            <td class="type"><a><xsl:attribute name="href"><xsl:text>?query=</xsl:text><xsl:value-of select="//@query-no-types"/></xsl:attribute> All Results</a></td>

            <!-- individuals -->
            <td class="icon"><a><xsl:attribute name="href"><xsl:text>?query=</xsl:text><xsl:value-of select="//@query-no-types"/><xsl:text>+type:individual</xsl:text></xsl:attribute><img src="/res/old/report_resources/apipe_dashboard/images/icons/individual_16.png" /></a></td>
            <td class="type"><a><xsl:attribute name="href"><xsl:text>?query=</xsl:text><xsl:value-of select="//@query-no-types"/><xsl:text>+type:individual</xsl:text></xsl:attribute> Individuals</a></td>

            <!-- models -->
            <td class="icon"><a><xsl:attribute name="href"><xsl:text>?query=</xsl:text><xsl:value-of select="//@query-no-types"/><xsl:text>+type:model</xsl:text></xsl:attribute><img src="/res/old/report_resources/apipe_dashboard/images/icons/model_16.png" /></a></td>
            <td class="type"><a><xsl:attribute name="href"><xsl:text>?query=</xsl:text><xsl:value-of select="//@query-no-types"/><xsl:text>+type:model</xsl:text></xsl:attribute> Models</a></td>

            <!-- flow cells-->
            <td class="icon"><a><xsl:attribute name="href"><xsl:text>?query=</xsl:text><xsl:value-of select="//@query-no-types"/><xsl:text>+type:illumina_run</xsl:text></xsl:attribute><img src="/res/old/report_resources/apipe_dashboard/images/icons/instrument_data_16.png" /></a></td>
            <td class="type"><a><xsl:attribute name="href"><xsl:text>?query=</xsl:text><xsl:value-of select="//@query-no-types"/><xsl:text>+type:illumina_run</xsl:text></xsl:attribute> Flow cells</a></td>

            <!-- mail -->
            <td class="icon"><a><xsl:attribute name="href"><xsl:text>?query=</xsl:text><xsl:value-of select="//@query-no-types"/><xsl:text>+type:mail</xsl:text></xsl:attribute><img src="/res/old/report_resources/apipe_dashboard/images/icons/mail_16.png" /></a></td>
            <td class="type"><a><xsl:attribute name="href"><xsl:text>?query=</xsl:text><xsl:value-of select="//@query-no-types"/><xsl:text>+type:mail</xsl:text></xsl:attribute> Mail</a></td>

            <!-- wiki
            <td class="icon"><a><xsl:attribute name="href"><xsl:text>index.cgi?query=</xsl:text><xsl:value-of select="//@query-no-types"/><xsl:text>+type:wiki</xsl:text></xsl:attribute><img src="/resources/report_resources/apipe_dashboard/images/icons/wiki_16.png" /></a></td>
            <td class="type"><a><xsl:attribute name="href"><xsl:text>index.cgi?query=</xsl:text><xsl:value-of select="//@query-no-types"/><xsl:text>+type:wiki</xsl:text></xsl:attribute> Wiki</a></td>
  -->

          </tr>
        </table>
      </div>
    </div>


    <div class="page_padding">
      <h1 class="results_header"><xsl:value-of select="@num-found"/> results found:</h1>
      <xsl:for-each select="result">
        <!-- Pre-generated HTML from a View module -->
        <xsl:value-of disable-output-escaping="yes" select='.'/>
      </xsl:for-each>
      <div class="pager">
      <xsl:choose>
        <xsl:when test="string(page-info/@previous-page)">
          <a><xsl:attribute name="href"><xsl:text>/view/genome/search/query/status.html?query=</xsl:text><xsl:value-of select="@query"/><xsl:text>&amp;page=</xsl:text><xsl:value-of select="page-info/@previous-page" /></xsl:attribute>
            <img src="/res/old/report_resources/jquery/dataTables-1.5/media/images/back_enabled.png" />
          </a>
        </xsl:when>
        <xsl:otherwise>
          <img src="/res/old/report_resources/jquery/dataTables-1.5/media/images/back_disabled.png" />
        </xsl:otherwise>
      </xsl:choose>
       Page <xsl:value-of select="page-info/@current-page" /> of <xsl:value-of select="page-info/@last-page" />. 
      <xsl:choose>
        <xsl:when test="string(page-info/@next-page)">
          <a>
            <xsl:attribute name="href"><xsl:text>/view/genome/search/query/status.html?query=</xsl:text><xsl:value-of select="@query"/><xsl:text>&amp;page=</xsl:text><xsl:value-of select="page-info/@next-page" /></xsl:attribute>
            <img src="/res/old/report_resources/jquery/dataTables-1.5/media/images/forward_enabled.png" />
          </a>
        </xsl:when>
        <xsl:otherwise>
          <img src="/res/old/report_resources/jquery/dataTables-1.5/media/images/forward_disabled.png" />
        </xsl:otherwise>
      </xsl:choose>
      </div>
    </div>

  </xsl:template>

</xsl:stylesheet> 
