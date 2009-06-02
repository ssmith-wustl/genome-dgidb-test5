<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
<xsl:output method="html" indent="yes"/>  
<xsl:template match="/">
<html>
  <head>
    <title>Build <xsl:value-of select="report/report-meta/generator-params/@build-id"/> Status</title>
    <title>Build <xsl:value-of select="report/report-meta/@name"/> Status</title>
  </head>
  <body>
  </body>
</html>
</xsl:template>
</xsl:stylesheet>
