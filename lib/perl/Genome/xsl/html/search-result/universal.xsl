<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template name="universal_search_result" match="/solr-results/doc">

    <div class="search_result">
      <div class="result_icon genome_model_32">
        <br/>
      </div>
      <div class="result">
        <h3><xsl:value-of select="field[@name='type']"/>: <xsl:value-of select="field[@name='object_id']"/></h3>
        <p class="resource_buttons">


        </p>

        <p class="result_summary">
          <xsl:value-of select="field[@name='content']"/>
        </p>
      </div>
    </div> <!-- end search_result -->

  </xsl:template>

</xsl:stylesheet>
