<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">


  <xsl:template name="genome_search" match="object[./types[./isa[@type='Genome::Search']]]">

    <script type="text/javascript" src="/res/js/app/genome_search.js"></script>

    <xsl:call-template name="control_bar_app"/>

    <div class="content rounded shadow" style="padding-top: 0;">
      <xsl:call-template name="app_header">
        <xsl:with-param name="app_name" select="'Analysis Search'"/>
        <xsl:with-param name="icon" select="'app_analysis_search_32'"/>
      </xsl:call-template>

      <div class="container">
        <div class="span-12">
          <div class="main_search">
            <form id="searchForm" method="get" action="/view/genome/search/query/status.html">
              <h4>Please enter your search, then press Return:</h4>

              <table cellpadding="0" cellspacing="0" border="0" class="search_elements">
                <tr>
                  <td>
                    <input class="query_box rounded" type="text" id="searchBox" name="query"/>
                  </td>
                  <td>
                    <input id="searchButton" type="submit" class="button" value="Search"/>
                  </td>
                </tr>
              </table>
            </form>
          </div>
<br/>
        </div> <!-- end .span-12 -->
        <div class="span-12 last">
          <br/>
        </div>
        <hr class="space"/>
<h2><font color="red">** This search engine is currently under maintenance **</font></h2>
When the maintenance is done (Monday March 21), search results will look a little different but 
queries will return results much quicker.
        <div class="main_search_hints clearfix">
          <div class="box_header span-8 last rounded-top">
            <div class="box_title"><h3 class="nontyped last">Can't find what you're looking for?</h3></div>
          </div>

          <div class="box_content rounded-bottom span-24 last">
            <div style="width: 100%; float: left;">
              <div class="padding10">
                <br/>
                Help us make it better by <a href="mailto:apipe@genome.wustle.du">emailing us</a> with
                your search text and what you expected to find.
                <br/><br/>
                Currently you will find taxons, individuals, samples, libraries, model groups, models, processing profiles, wiki pages, and instrument data (flow cell).
                <br/>
                <br/>
                <br/>
                <br/>
              </div><!-- end .padding10 -->
            </div>
          </div> <!-- end .box_content -->
        </div><!-- end .main_search_hints -->

      </div> <!-- end .container  -->
    </div> <!-- end .content  -->

    <xsl:call-template name="footer">
      <xsl:with-param name="footer_text">
        <br/>
      </xsl:with-param>
    </xsl:call-template>

  </xsl:template>

</xsl:stylesheet>
