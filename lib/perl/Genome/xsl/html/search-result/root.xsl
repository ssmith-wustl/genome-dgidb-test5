<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:strip-space elements="*"/>

  <!--
      #############################################
      BASE PAGE TEMPLATE
      #############################################
  -->

  <xsl:template match="/">
    <xsl:apply-templates/>
  </xsl:template>

  <!--
      #############################################
      PAGE COMPONENT TEMPLATES
      #############################################
  -->
  <!-- creates a button with a jQueryUI icon -->
  <xsl:template name="object_link_button">
    <xsl:param name="type" select="./@type"/>
    <xsl:param name="id" select="./@id"/>
    <xsl:param name="perspective" select="'status'"/>
    <xsl:param name="toolkit" select="'html'"/>
    <xsl:param name="linktext" select="./aspect[@name='name']/value"/>
    <xsl:param name="icon"/>

    <xsl:comment>template: search-result/root.xsl:object_link_button</xsl:comment>

    <a class="mini btn">
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
      <span class="sm-icon sm-icon-extlink"><xsl:attribute name="class"><xsl:text>sm-icon </xsl:text><xsl:value-of select="$icon"/></xsl:attribute><br/></span><xsl:value-of select="$linktext"/>
    </a>

  </xsl:template>


</xsl:stylesheet>
