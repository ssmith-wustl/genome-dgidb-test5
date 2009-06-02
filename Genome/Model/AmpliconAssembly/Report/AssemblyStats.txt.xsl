<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
<xsl:output method="text" indent="no"/>  
<xsl:template match="/">
Summary for Amplicon Assembly Model (Name: <xsl:value-of select="report/report-meta/@name"/> Build Id:<xsl:value-of select="report/report-meta/generator-params/@build-id"/>)
<xsl:variable name="stats" select="report/datasets/stats/stat"/>
------------------------
Stats 
------------------------

Attempted <xsl:value-of select="$stats/@attempted"/>
Assembled <xsl:value-of select="$stats/assembled"/>
Assembly Success <xsl:value-of select="$stats/assembly-success"/>%

Length Average <xsl:value-of select="$stats/length-average"/>
Length Median <xsl:value-of select="$stats/length-median"/>
Length Maximum <xsl:value-of select="$stats/length-maximum"/>
Length Minimum <xsl:value-of select="$stats/length-minimum"/>

Quality Base Average <xsl:value-of select="$stats/quality-base-average"/>
Quality >= 20 per Assembly <xsl:value-of select="$stats/quality-less-than-20-bases-per-assembly"/>

Reads Assembled <xsl:value-of select="$stats/reads-assembled"/>
Reads Total <xsl:value-of select="$stats/reads"/>
Reads Assembled Success <xsl:value-of select="$stats/reads-assembled-success"/>%
Reads Assembled Average <xsl:value-of select="$stats/reads-assembled-average"/>
Reads Assembled Median <xsl:value-of select="$stats/reads-assembled-median"/>
Reads Assembled Maximum <xsl:value-of select="$stats/reads-assembled-maximum"/>
Reads Assembled Minimum <xsl:value-of select="$stats/reads-assembled-minimum"/>

------------------------

For full report, including quality hisotgram go to:
http://

</xsl:template>
</xsl:stylesheet>
