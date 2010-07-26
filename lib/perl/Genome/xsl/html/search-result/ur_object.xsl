<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
xmlns:rest="urn:rest">

  <xsl:template name="ur_object" match="object">
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
            <xsl:value-of select="label_name"/>:
          </span>
          <span class="title">
            <xsl:call-template name="object_link">
              <xsl:with-param name="linktext" select="display_name"/>
            </xsl:call-template>
          </span>
        </h2>
      </div>
      </td></tr></tbody></table>
    </div>
  </xsl:template>

  <xsl:template name="object_link">
    <xsl:param name="type" select="./@type"/>
    <xsl:param name="id" select="./@id"/>
    <xsl:param name="perspective" select="'status'"/>
    <xsl:param name="toolkit" select="'html'"/>
    <xsl:param name="linktext" select="./aspect[@name='name']/value"/>
    <a>
      <xsl:attribute name="href">
        <xsl:value-of select="$rest"/>
        <xsl:text>/</xsl:text>
        <xsl:value-of select="rest:typetourl($type)"/>
        <xsl:text>/</xsl:text>
        <xsl:value-of select="$perspective"/>
        <xsl:text>.</xsl:text>
        <xsl:value-of select="$toolkit"/>
        <xsl:text>?id=</xsl:text>
        <xsl:value-of select="$id"/>
      </xsl:attribute>
      <xsl:value-of select="$linktext"/>
    </a>
  </xsl:template>

  <xsl:template name="string-replace-all">
    <xsl:param name="text" />
    <xsl:param name="replace" />
    <xsl:param name="by" />
    <xsl:choose>
      <xsl:when test="contains($text, $replace)">
        <xsl:value-of select="substring-before($text,$replace)" />
        <xsl:value-of select="$by" />
        <xsl:call-template name="string-replace-all">
          <xsl:with-param name="text"
                          select="substring-after($text,$replace)" />
          <xsl:with-param name="replace" select="$replace" />
          <xsl:with-param name="by" select="$by" />
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$text" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
</xsl:stylesheet>
