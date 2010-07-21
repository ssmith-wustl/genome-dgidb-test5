<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template name="genome_object_set" match="object[./types[./isa[@type='UR::Object::Set']]]">
    <div class="result">
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="result"><tbody><tr>
      <td>
        <!-- <div class="icon">
          <img width="32" height="32" src="/res/old/report_resources/apipe_dashboard/images/icons/model_32.png" />
        </div> -->
      </td><td>
        <div class="description">
        <h2 class="name">
          <span class="label">
            Results: <xsl:value-of select="aspect[@name='rule_display']/value" />
          </span>
          <span class="title"> 
            <xsl:value-of select="aspect[@name='rule']/object/display_name"/>
          </span>
        </h2>
      </div>
      </td></tr></tbody></table>
    </div>
    <xsl:for-each select="aspect[@name='members']">
      <xsl:apply-templates />
    </xsl:for-each>
  </xsl:template>

</xsl:stylesheet>
