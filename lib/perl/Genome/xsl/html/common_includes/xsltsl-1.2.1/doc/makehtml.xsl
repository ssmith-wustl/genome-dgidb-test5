<xsl:stylesheet version='1.1'	xmlns:xsl='http://www.w3.org/1999/XSL/Transform'	xmlns:build='http://xsltsl.org/xsl/build/1.0'>  <xsl:import href='jrefhtml.xsl'/>  <xsl:output        method="html"        indent="yes"        encoding="ISO-8859-1"/>  <xsl:template match='/'>    <xsl:apply-templates/>  </xsl:template>  <xsl:template match='build:sources'>    <xsl:apply-templates/>  </xsl:template>  <xsl:template match='build:stylesheet'>    <xsl:message>Making <xsl:value-of select='concat(substring-before(substring(., 4), ".xsl"), ".html")'/>&#10;</xsl:message>    <xsl:document href='{substring-before(substring(., 4), ".xsl")}.html' method='html'>      <xsl:apply-templates select='document(concat(substring-before(substring(., 4), ".xsl"), ".xml"))'/>    </xsl:document>  </xsl:template>  <xsl:template match='build:document'>    <xsl:message>Making <xsl:value-of select='concat(substring-before(., ".xml"), ".html")'/>&#10;</xsl:message>    <xsl:document href='{substring-before(substring(., 4), ".xml")}.html' method='html'>      <xsl:apply-templates select='document(.)'/>    </xsl:document>  </xsl:template></xsl:stylesheet>