<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">


  <xsl:template name="genome_search" match="object[./types[./isa[@type='Genome::Search']]]">
    <div class="content rounded shadow" style="padding-top: 0;">
      <xsl:call-template name="app_header">
        <xsl:with-param name="app_name" select="'Analysis Search'"/>
        <xsl:with-param name="icon" select="'app_analysis_search_32'"/>
      </xsl:call-template>

      <div class="container">
        <div class="span-6">
          <br/>
        </div>
        <div class="span-12">
          <div class="main_search">
            <form method="get" action="/view/genome/search/query/status.html">
              <h4>Please enter your search, then press Return:</h4>
              <table cellpadding="0" cellspacing="0" border="0" class="search_elements">
                <tr>
                  <td>
                    <input class="query_box rounded" type="text" name="query"/>
                  </td>
                  <td>
                    <input type="submit" class="button" value="Search"/>
                  </td>
                </tr>
              </table>
            </form>
          </div>

          <div class="main_search_hints clearfix">
            <div class="box_header span-8 last rounded-top">
              <div class="box_title"><h3 class="nontyped span-7 last">Advanced Search Techniques</h3></div>
              <div class="box_button">

              </div>
            </div>

            <div class="box_content rounded-bottom span-8 last">
              <div class="padding10">
                <p>The search engine that drives Analysis Search, Lucene/Solr, provides the following advanced methods to improve your searches. For more detailed instructions, please <a href="http://lucene.apache.org/java/2_4_0/queryparsersyntax.html">consult the documentation</a>.</p>


                <p><strong>Wildcard Searches</strong><br/>
                To perform a single character wildcard search use the "?" symbol. To perform a multiple character wildcard search use the "*" symbol. These wildcard characters only function within and at the end of words.<br/>
                <strong>Example: </strong> <span style="font-family: monospace;">bacter*</span> will match "bacteria", "bacterial", "bacterias", etc.</p>

                <p><strong>Fields</strong><br/>
                Narrow your search by using fields. The current schema contains the fields title, class, label_name, and description. <strong>[more?]</strong>
                <br/>
                <strong>Example:</strong> including <span style="font-family: monospace;">class:"Genome::Model"</span> will limit your search to models.</p>

                <p><strong>Fuzzy Search</strong><br/>
                By adding a tilde (~) to the end of a word, you instruct the seach engine to return results containing strings that are "close to" the word.
                <br/>
                <strong>Example:</strong> searching for <span style="font-family: monospace;">roam~</span> will return results containing "foam" and "roams".</p>

                <p><strong>Proximity Search</strong><br/>
                To search for proximal words, append a tilde and a number indicating the range of the proximal search to a quoted string containing the words you're searching for.
                <br/>
                <strong>Example:</strong> searching for <span style="font-family: monospace;">"BWA samtools"~10</span> will return results in which "BWA" occurs within 10 words of "samtools".</p>

                <p><strong>Boosting a Term</strong><br/>
                You may "boost" a search term to make it more relevant to your search by appending a caret (^) and a boost factor to the end of the term. The boost syntax works with words or phrases.
                <br/>
                <strong>Example: </strong> <span style="font-family: monospace;">BWA^4 samtools</span> will return results with "BWA" weighted 4 times more relevant than "samtools".</p>



              </div><!-- end .padding10 -->
            </div> <!-- end .box_content -->
          </div><!-- end .main_search_hints -->
        </div> <!-- end .span-12 -->
        <div class="span-6 last">
          <br/>
        </div>
      </div> <!-- end .container  -->
    </div> <!-- end .content  -->

    <xsl:call-template name="footer">
      <xsl:with-param name="footer_text">
        <br/>
      </xsl:with-param>
    </xsl:call-template>

  </xsl:template>

</xsl:stylesheet>
