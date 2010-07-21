<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template name="genome_library" match="object[./types[./isa[@type='Genome::Library']]]">
    <div class="result">
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="result"><tbody><tr>
      <td>
        <div class="icon">
           <xsl:call-template name="object_link">
             <xsl:with-param name="linktext">
              <img width="32" height="32" src="/res/old/report_resources/apipe_dashboard/images/icons/individual_32.png" />
            </xsl:with-param>
          </xsl:call-template>
        </div>
      </td><td>
        <div class="description">
        <h2 class="name">
          <span class="label">
            Library:
          </span>
          <span class="title"> 
            <xsl:call-template name="object_link" />
          </span>
        </h2>
      </div>
      </td></tr></tbody></table>
    </div>
    <xsl:for-each select="aspect[@name='sample']/object">
      <xsl:call-template name="genome_sample"/>
    </xsl:for-each>
    <xsl:for-each select="aspect[@name='taxon']/object">
      <xsl:call-template name="genome_taxon"/>
    </xsl:for-each>
  </xsl:template>

</xsl:stylesheet> 