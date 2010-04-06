<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template name="ur_object" match="object">
    <div class="object">
      <div class="identity">
        <div class="display_name">
          <xsl:apply-templates select="display_name"/>
        </div>
        <div class="representation">
          <div class="type">
            <span><xsl:value-of select="@type"/></span>
          </div>
          <div class="id">
            <xsl:variable name="prettyId">
              <xsl:call-template name="string-replace-all">
                <xsl:with-param name="text" select="@id"/>
                <xsl:with-param name="replace" select="'%09'"/>
                <xsl:with-param name="by" select="' '"/>
              </xsl:call-template>
            </xsl:variable>
            <span><xsl:value-of select="$prettyId" /></span>
          </div>
        </div>
        <br/>
      </div>
      <xsl:if test="count(aspect) > 0">
        <div class="aspects">
          <table class="aspects">
            <tbody>
              <xsl:for-each select="aspect">
                <tr>
                  <td>
                    <xsl:value-of select="@name"/>
                  </td>
                  <td><xsl:apply-templates/></td>
                </tr>
              </xsl:for-each>
            </tbody>
          </table>
        </div>
      </xsl:if>
    </div>
  </xsl:template>

<!--  <xsl:template match="object[@type='UR::Object::Property']">
    <code><xsl:value-of select="@id"/></code><br/>
  </xsl:template>> -->

  <xsl:template match="display_name">
    <xsl:variable name="typeLink">
      <xsl:call-template name="string-replace-all">
        <xsl:with-param name="text" select="../@type"/>
        <xsl:with-param name="replace" select="'::'"/>
        <xsl:with-param name="by" select="'/'"/>
      </xsl:call-template>
    </xsl:variable>
    <span>
      <a>
        <xsl:attribute name="href">
          <xsl:value-of select="$rest"/>
          <xsl:text>/</xsl:text>
          <xsl:value-of select="$typeLink"/>
          <xsl:text>/</xsl:text>
          <xsl:value-of select="$currentPerspective"/>
          <xsl:text>.</xsl:text>
          <xsl:value-of select="$currentToolkit"/>
          <xsl:text>?id=</xsl:text>
          <xsl:value-of select="../@id"/>
        </xsl:attribute>
        <xsl:value-of select="."/>
      </a>
    </span>
  </xsl:template>

  <xsl:template match="exception">
    <code>[!] Exception</code><br/>
  </xsl:template>

  <xsl:template match="value">
    <code><xsl:value-of select="."/></code><br/>
  </xsl:template>

  <xsl:template match="perldata/scalar">
    <code><xsl:value-of select="."/></code><br/> 
  </xsl:template>

  <xsl:template match="perldata/scalarref">
    <code><xsl:value-of select="."/></code><br/>
  </xsl:template>

  <xsl:template match="perldata/arrayref">
    <code><xsl:value-of select="@blessed_package"/>=ARRAY(<xsl:value-of select="@memory_address"/>)</code><br/>
  </xsl:template>

  <xsl:template match="perldata/hashref">
    <code><xsl:value-of select="@blessed_package"/>=HASH(<xsl:value-of select="@memory_address"/>)</code><br/>
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
