<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template name="genome_disk_group" match="object[./types[./isa[@type='Genome::Disk::Group']]]">
    <xsl:variable name="href">
      <xsl:text>/disk/allocationmonitor/listvolumes?disk_group_name=</xsl:text><xsl:value-of select="normalize-space(aspect[@name='disk_group_name']/value)" />
    </xsl:variable>
    <div class="result">
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="result"><tbody><tr>
      <td>
        <div class="icon">
          <a>
            <xsl:attribute name="href"><xsl:value-of select="$href"/></xsl:attribute>
            <img width="32" height="32" src="/res/old/report_resources/apipe_dashboard/images/icons/eye_16.png" />
          </a>
        </div>
      </td><td width="100%">
        <div class="description">
        <h2 class="name">
          <span class="label">
            Disk Group:
          </span>
          <span class="title">
            <a>
              <xsl:attribute name="href"><xsl:value-of select="$href"/></xsl:attribute>
              <xsl:value-of select="aspect[@name='disk_group_name']/value" />
            </a>
          </span>
        </h2>
        <p class="blurb">
          <xsl:value-of select="aspect[@name='user_name']/value"/>
          <xsl:value-of select="aspect[@name='group_name']/value"/>
        </p>
      </div>
      </td></tr></tbody></table>
    </div>
  </xsl:template>

</xsl:stylesheet>
