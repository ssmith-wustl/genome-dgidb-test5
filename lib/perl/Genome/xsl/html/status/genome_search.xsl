<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">


  <xsl:template name="genome_search" match="object[./types[./isa[@type='Genome::Search']]]">
    <script type="text/javascript">
      (function($) {
        $("div.search_form_container").width(930);
        $("div.page_padding").css("padding","0px");
      })(jQuery);
    </script> 
    <div class="search_form_container">
      <div class="search_form">
        <form method="get" action="/view/genome/search/query/status.html">
          <table cellspacing="0" cellpadding="0" border="0" class="form">
            <tr>
              <td>
                <input type="text" size="30" style="background-color: #FFF; font-size: 120%;" name="query"/><br/>
              </td>
              <td>
                <input type="submit" value="Search"/>
              </td>
            </tr>
          </table>
        </form>
      </div>
      <div class="search_help">
        <p></p>
      </div>
    </div>
    <div style="float: left; padding-top: 20px; padding-bottom: 200px; padding-left: 20px;">
        <h2>Please enter your search in the form above.</h2>
Read about <a href="http://lucene.apache.org/java/2_3_2/queryparsersyntax.html"> search syntax here</a>.
    </div>

  </xsl:template>

</xsl:stylesheet> 
