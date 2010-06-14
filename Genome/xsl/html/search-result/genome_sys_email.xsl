<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template name="genome_sys_email" match="object[./types[./isa[@type='Genome::Sys::Email']]]">
    <xsl:variable name="message_url_base">
      <xsl:value-of select="normalize-space(aspect[@name='mail_server_path']/value)"/>
      <xsl:text>/</xsl:text>
      <xsl:value-of select="normalize-space(aspect[@name='list_name']/value)"/>
      <xsl:text>/</xsl:text>
      <xsl:value-of select="normalize-space(aspect[@name='month']/value)"/>
      <xsl:text>/</xsl:text>
    </xsl:variable>
    <div class="result">
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="result"><tbody><tr>
      <td>
        <div class="icon">
          <a>
            <xsl:attribute name="href">
              <xsl:value-of select="$message_url_base"/>
              <xsl:value-of select="normalize-space(aspect[@name='message_id']/value)" />
              <xsl:text>.html</xsl:text>
            </xsl:attribute>
            <img width="32" height="32" src="/res/old/report_resources/apipe_dashboard/images/icons/mail_32.png" />
          </a>
        </div>
      </td><td width="100%">
        <div class="description">
        <h2 class="name">
          <span class="label">
            Mail:
          </span>
          <span class="title">
            <a>
              <xsl:attribute name="href">
                <xsl:value-of select="$message_url_base"/>
                <xsl:value-of select="normalize-space(aspect[@name='message_id']/value)" />
                <xsl:text>.html</xsl:text>
              </xsl:attribute>
              <xsl:value-of select="aspect[@name='subject']/value"/>
            </a>
          </span>
        </h2>
        <p class="blurb">
          <xsl:value-of select="aspect[@name='blurb']/value"/>
        </p>
        <p class="info">
          <a>
            <xsl:attribute name="href">
              <xsl:value-of select="normalize-space(aspect[@name='mail_list_path']/value)"/>
              <xsl:text>/</xsl:text>
              <xsl:value-of select="normalize-space(aspect[@name='list_name']/value)"/>
            </xsl:attribute>
            <xsl:value-of select="normalize-space(aspect[@name='list_name']/value)"/>
          </a>
          | <a>
            <xsl:attribute name="href">
              <xsl:value-of select="$message_url_base"/>
              <xsl:text>date.html</xsl:text>
            </xsl:attribute>
            <xsl:value-of select="normalize-space(aspect[@name='month']/value)"/>
          </a>
        </p>
      </div>
      </td></tr></tbody></table>
    </div>
  </xsl:template>

</xsl:stylesheet>
