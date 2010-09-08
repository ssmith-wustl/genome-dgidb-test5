<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:rest="urn:rest">
  <xsl:template name="ur_object_header" match="/object">
    <xsl:comment>template: status/ur_object.xsl:ur_object_header  match: /object</xsl:comment>
    <div class="object">
      <div class="header_object">
        <div class="display_name">
          <xsl:call-template name="header_display_name"/>
        </div>
      </div>
      <div class="content">
        <xsl:if test="count(aspect) > 0">
          <div class="aspects">
            <table class="aspects" cellpadding="0" cellspacing="0" border="0">
              <tbody>
                <xsl:for-each select="aspect">
                  <tr>
                    <td class="name">
                      <strong><xsl:value-of select="@name"/></strong>
                    </td>
                    <td class="value">
                      <xsl:choose>
                        <xsl:when test="normalize-space(.)">
                          <xsl:apply-templates/>
                        </xsl:when>
                        <xsl:otherwise>
                          <p>--</p>
                        </xsl:otherwise>
                      </xsl:choose>
                    </td>
                  </tr>
                </xsl:for-each>
              </tbody>
            </table>
          </div>
        </xsl:if>
      </div>
    </div>

  </xsl:template>

  <xsl:template name="header_display_name">
    <xsl:comment>template: status/ur_object.xsl:header_display_name match: header_display_name</xsl:comment>
    <span style="font-weight: bold;">
      <h1>
        <xsl:value-of select="@type"/><span class="id"> (<xsl:value-of select="display_name"/>)</span>
      </h1>
    </span>
  </xsl:template>

  <xsl:template name="ur_object" match="object">
    <xsl:comment>template: status/ur_object.xsl:ur_object match: object</xsl:comment>
    <p>
      <xsl:apply-templates select="display_name"/>
    </p>
    <xsl:if test="count(aspect) > 0">
      <div class="aspects">
        <table class="aspects" cellpadding="0" cellspacing="0" border="0">
          <tbody>
            <xsl:for-each select="aspect">
              <tr>
                <td class="name">
                  <strong><xsl:value-of select="@name"/></strong>
                </td>
                <td class="value"><xsl:apply-templates/></td>
              </tr>
            </xsl:for-each>
          </tbody>
        </table>
      </div>
    </xsl:if>
  </xsl:template>

  <xsl:template match="display_name">
    <xsl:comment>
      template: status/ur_object.xsl:display_name match: display_name
    </xsl:comment>
    <xsl:variable name="typeLink">
      <xsl:value-of select="rest:typetourl(../@type)" />
    </xsl:variable>
    <span>
      <span class="display_name"><xsl:value-of select="../@type"/></span><span class="id"> (<a>
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
      </a>)</span>
    </span>
  </xsl:template>

  <xsl:template match="exception">
    <xsl:comment>
      template: status/ur_object.xsl:exception match: exception
    </xsl:comment>
    <p class="exception">
      Exception <span class="trigger">[toggle view]</span>
    </p>
    <div class="toggle_container">
      <p><xsl:value-of select="."/></p>
    </div>
  </xsl:template>

  <xsl:template match="value">
    <xsl:comment>
      match: value
    </xsl:comment>
    <p><xsl:value-of select="."/></p>
  </xsl:template>

  <xsl:template match="perldata/scalar">
    <xsl:comment>
      match: perldata/scalar
    </xsl:comment>
    <p><xsl:value-of select="."/></p>
  </xsl:template>

  <xsl:template match="perldata/scalarref">
    <xsl:comment>
      match: perldata/scalarref
    </xsl:comment>
    <p><xsl:value-of select="."/></p>
  </xsl:template>

  <xsl:template match="perldata/arrayref">
    <xsl:comment>
      match: perldata/arrayref
    </xsl:comment>
    <p><xsl:value-of select="@blessed_package"/>=ARRAY(<xsl:value-of select="@memory_address"/>)</p>
  </xsl:template>

  <xsl:template match="perldata/hashref">
    <xsl:comment>
      match: perldata/hashref
    </xsl:comment>
    <p><xsl:value-of select="@blessed_package"/>=HASH(<xsl:value-of select="@memory_address"/>) <span class="trigger">[toggle view]</span></p>
    <div class="toggle_container">
      <table class="hash">
        <tbody>
          <xsl:for-each select="item">
            <tr>
              <td class="name"><xsl:value-of select="@key"/></td>
              <td class="value"><xsl:value-of select="."/></td>
            </tr>
          </xsl:for-each>
        </tbody>
      </table>
    </div>
  </xsl:template>

  <xsl:template name="object_link_href">
    <xsl:param name="type" select="./@type"/>
    <xsl:param name="id" select="./@id"/>
    <xsl:param name="perspective" select="'status'"/>
    <xsl:param name="toolkit" select="'html'"/>

    <xsl:value-of select="$rest"/>
    <xsl:text>/</xsl:text>
    <xsl:value-of select="rest:typetourl($type)"/>
    <xsl:text>/</xsl:text>
    <xsl:value-of select="$perspective"/>
    <xsl:text>.</xsl:text>
    <xsl:value-of select="$toolkit"/>
    <xsl:text>?id=</xsl:text>
    <xsl:value-of select="$id"/>
  </xsl:template>

  <xsl:template name="object_link">
    <xsl:param name="type" select="./@type"/>
    <xsl:param name="id" select="./@id"/>
    <xsl:param name="perspective" select="'status'"/>
    <xsl:param name="toolkit" select="'html'"/>
    <xsl:param name="linktext" select="./aspect[@name='name']/value"/>

    <a>
      <xsl:attribute name="href">
        <xsl:call-template name="object_link_href">
          <xsl:with-param name="type" select="$type"/>
          <xsl:with-param name="id" select="$id"/>
          <xsl:with-param name="perspective" select="$perspective"/>
          <xsl:with-param name="toolkit" select="$toolkit"/>
        </xsl:call-template>
      </xsl:attribute>
      <xsl:copy-of select="$linktext"/>
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

  <!-- creates a button with a jQueryUI icon -->
  <xsl:template name="object_link_button">
    <xsl:param name="type" select="./@type"/>
    <xsl:param name="id" select="./@id"/>
    <xsl:param name="perspective" select="'status'"/>
    <xsl:param name="toolkit" select="'html'"/>
    <xsl:param name="linktext" select="./aspect[@name='name']/value"/>
    <xsl:param name="icon"/>

    <xsl:comment>template: search/ur_object.xsl; name: object_link_button</xsl:comment>

    <a class="mini btn">
      <xsl:attribute name="href">
        <xsl:call-template name="object_link_href">
          <xsl:with-param name="type" select="$type"/>
          <xsl:with-param name="id" select="$id"/>
          <xsl:with-param name="perspective" select="$perspective"/>
          <xsl:with-param name="toolkit" select="$toolkit"/>
        </xsl:call-template>
      </xsl:attribute>
      <span class="sm-icon sm-icon-extlink"><xsl:attribute name="class"><xsl:text>sm-icon </xsl:text><xsl:value-of select="$icon"/></xsl:attribute><br/></span><xsl:value-of select="$linktext"/>
    </a>

  </xsl:template>

  <!-- creates a tiny button with no label -->
  <xsl:template name="object_link_button_tiny">
    <xsl:param name="type" select="./@type"/>
    <xsl:param name="id" select="./@id"/>
    <xsl:param name="perspective" select="'status'"/>
    <xsl:param name="toolkit" select="'html'"/>
    <xsl:param name="icon"/>

    <xsl:variable name="button_href">
      <xsl:call-template name="object_link_href">
        <xsl:with-param name="type" select="$type"/>
        <xsl:with-param name="id" select="$id"/>
        <xsl:with-param name="perspective" select="$perspective"/>
        <xsl:with-param name="toolkit" select="$toolkit"/>
      </xsl:call-template>
    </xsl:variable>

    <xsl:comment>template: status/ur_object.xsl:object_link_button_tiny</xsl:comment>

    <a class="mini-icon btn">
      <xsl:attribute name="href">
        <xsl:value-of select="$button_href"/>
      </xsl:attribute>
      <span><xsl:attribute name="class"><xsl:text>sm-icon </xsl:text><xsl:value-of select="$icon"/></xsl:attribute><br/></span>
    </a>

  </xsl:template>


  <!-- function takes input string and returns string after substr  -->
  <xsl:template name="substring-after-last">
    <xsl:param name="input"/>
    <xsl:param name="substr"/>

    <!-- Extract the string which comes after the first occurrence -->
    <xsl:variable name="temp" select="substring-after($input,$substr)"/>

    <xsl:choose>
      <!-- If it still contains the search string the recursively process -->
      <xsl:when test="$substr and contains($temp,$substr)">
        <xsl:call-template name="substring-after-last">
          <xsl:with-param name="input" select="$temp"/>
          <xsl:with-param name="substr" select="$substr"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$temp"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>


</xsl:stylesheet>
