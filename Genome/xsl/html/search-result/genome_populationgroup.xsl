<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template name="genome_populationgroup" match="object[./types[./isa[@type='Genome::PopulationGroup']]]">
    <div class="result">
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="result"><tbody><tr>
      <td>
        <div class="icon">
          <xsl:call-template name="object_link">
            <xsl:with-param name="linktext">
              <img width="32" height="32" src="/res/old/report_resources/apipe_dashboard/images/icons/genome_populationgroup_16.png"/>
            </xsl:with-param>
          </xsl:call-template>
        </div>
      </td><td>
        <div class="description">
        <h2 class="name">
          <span class="label">
            Population Group:
          </span>
          <span class="title">
            <xsl:call-template name="object_link">
              <xsl:with-param name="linktext">
	            <xsl:choose>
	              <xsl:when test="normalize-space(aspect[@name='common_name']/value)">
	                <xsl:value-of select="aspect[@name='common_name']/value"/>
	              </xsl:when>
	              <xsl:otherwise>
	                <xsl:value-of select="aspect[@name='name']/value"/>
	              </xsl:otherwise>
	            </xsl:choose>
	          </xsl:with-param>
            </xsl:call-template>
          </span>
        </h2>
        <p class="info">
          <xsl:value-of select="aspect[@name='description']/value"/>
        </p>
        <p class="blurb">
          Members: <xsl:for-each select="aspect[@name='members']/object">
            <xsl:choose>
              <xsl:when test="normalize-space(aspect[@name='common_name']/value)">
                <xsl:value-of select="aspect[@name='common_name']/value"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="aspect[@name='name']/value"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:for-each>
        </p>
      </div>
      </td></tr></tbody></table>
    </div>
  </xsl:template>

</xsl:stylesheet>
