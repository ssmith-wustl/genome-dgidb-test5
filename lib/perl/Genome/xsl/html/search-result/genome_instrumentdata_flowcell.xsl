<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template name="genome_instrumentdata_flowcell" match="object[./types[./isa[@type='Genome::InstrumentData::FlowCell']]]">
    <div class="result">
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="result"><tbody><tr>
      <td>
        <div class="icon">
          <xsl:call-template name="object_link">
            <xsl:with-param name="linktext">
              <img width="32" height="32" src="/res/old/report_resources/apipe_dashboard/images/icons/instrument_data_32.png" />
            </xsl:with-param>
          </xsl:call-template>
        </div>
      </td><td width="100%">
        <div class="description">
        <h2 class="name">
          <span class="label">
            Illumina flow cell:
          </span>
          <span class="title">
            <xsl:call-template name="object_link">
              <xsl:with-param name="linktext">
                <xsl:value-of select="aspect[@name='flow_cell_id']/value"/>
	          </xsl:with-param>
            </xsl:call-template>
          </span>
        </h2>
        <p class="blurb">
          <xsl:value-of select="aspect[@name='machine_name']/value"/> <xsl:value-of select="aspect[@name='run_name']/value"/> <xsl:value-of select="aspect[@name='run_type']/value"/>
        </p>
        <p class="info">
          <a><xsl:attribute name="href">/solexa/equipment/flowcell?flow_cell_id=<xsl:value-of select="normalize-space(aspect[@name='flow_cell_id']/value)"/></xsl:attribute>production</a>
          |
          <xsl:choose>
	        <xsl:when test="aspect[@name='lanes']/object">
	          <xsl:call-template name="object_link">
                <xsl:with-param name="linktext">
                  analysis
                </xsl:with-param>
              </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
               analysis
            </xsl:otherwise>
          </xsl:choose>
        </p>
      </div>
      </td></tr></tbody></table>
    </div>
  </xsl:template>

</xsl:stylesheet>
