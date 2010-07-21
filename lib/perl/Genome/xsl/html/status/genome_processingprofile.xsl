<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template name="genome_processingprofile" match="object[./types[./isa[@type='Genome::ProcessingProfile']]]">
    <div class="result">
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="result"><tbody><tr>
      <td>
        <div class="icon">
           <xsl:call-template name="object_link">
             <xsl:with-param name="linktext">
              <img width="32" height="32" src="/res/old/report_resources/apipe_dashboard/images/icons/eye_16.png" />
            </xsl:with-param>
          </xsl:call-template>
        </div>
      </td><td>
        <div class="description">
        <h2 class="name">
          <span class="label">
            Processing Profile:
          </span>
          <span class="title"> 
            <xsl:call-template name="object_link" />
          </span>
        </h2>
        <p class="info">
          <xsl:value-of select="aspect[@name='type_name']/value"/>
          <xsl:if test="normalize-space(aspect[@name='supersedes']/value)">
            (supersedes <xsl:value-of select="aspect[@name='supersedes']/value"/>)
          </xsl:if>
        </p>
        </div>
      </td></tr></tbody></table>
    </div>
    <xsl:if test="count(aspect[@name='params']) > 0 ">
      <table class="info_table">
      <xsl:for-each select="aspect[@name='params']/object">
        <tr>
          <td class="label"><xsl:value-of select="normalize-space(aspect[@name='name'])"/>:</td>
          <td class="value"><xsl:value-of select="aspect[@name='value']"/></td>
        </tr>
      </xsl:for-each>
      </table>
    </xsl:if>
    <xsl:if test="count(aspect[@name='models']/object) > 0">
	  Models:
	  <xsl:for-each select="aspect[@name='models']">
	    <xsl:call-template name="genome_model_build_table">
	      <xsl:with-param name="want_builds" value="0"/>
	    </xsl:call-template>
      </xsl:for-each>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>