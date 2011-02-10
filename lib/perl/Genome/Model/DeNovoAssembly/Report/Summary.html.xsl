<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="html"/>
  <xsl:output doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"/>
  <xsl:output doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"/>
  <xsl:template match="/">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
    <title><xsl:value-of select="//report-meta/description"/></title> 
    <link href="layout.css" rel="stylesheet" type="text/css"></link>
    <link rel="shortcut icon" href="https://imp.gsc.wustl.edu/static/report_resources/apipe_dashboard/images/gc_favicon.png" type="image/png"/>
    <link rel="stylesheet" href="https://imp.gsc.wustl.edu/static/report_resources/apipe_dashboard/css/master.css" type="text/css" media="screen"/>
    </head>
  <body>
    <div class="container"><div class="background">
      <h1 class="page_title"><xsl:value-of select="//report-meta/description"/></h1>
      <div class="page_padding">
        
      <h2 class="report_section">Model and Build Information</h2>
      <table width="100%" cellspacing="0" cellpadding="0" border="0" class="info_table_group">
      <tr>
      <td>
        <table width="100%" cellspacing="0" cellpadding="0" border="0" class="info_table">
        <colgroup>
          <col width="30%"/>
          <col width="70%"/>
        </colgroup>
        <tr>
          <td class="label" width="25%">Build Id</td>
          <td class="value"><xsl:value-of select="//model-info/build-id"/></td>
				</tr>
				<tr>
          <td class="label">Data Directory</td>
          <td class="value"><a><xsl:attribute name="href">https://gscweb.gsc.wustl.edu/<xsl:value-of select="//model-info/data-directory"/></xsl:attribute><xsl:text>View Directory</xsl:text></a></td>
				</tr>
				<tr>
          <td class="label" width="25%">Model Id</td>
				  <td class="value"><xsl:value-of select="//model-info/id"/></td>
				</tr>
				<tr>
          <td class="label" width="25%">Name</td>
				  <td class="value"><xsl:value-of select="//model-info/name"/></td>
				</tr>
				<tr>
          <td class="label">Subject</td>
				  <td class="value"><xsl:value-of select="//model-info/subject-name"/></td>
				</tr>
				<tr>
          <td class="label">Processing Profile</td>
				  <td class="value"><xsl:value-of select="//model-info/processing-profile-name"/></td>
				</tr>
				<tr>
          <td class="label">Seq Platform</td>
				  <td class="value"><xsl:value-of select="//model-info/sequencing-platform"/></td>
				</tr>
				<tr>
          <td class="label">Assembler</td>
				  <td class="value"><xsl:value-of select="//model-info/assembler-name"/></td>
				</tr>
				<tr>
          <td class="label">Assembler Version</td>
				  <td class="value"><xsl:value-of select="//model-info/assembler-version"/></td>
				</tr>
				<tr>
          <td class="label">Assembler Params</td>
          <td class="value"><xsl:value-of select="//model-info/assembler-params"/></td>
				</tr>
        <xsl:if test="//metric/assembler-kmer-used &gt; 0">
				<tr>
          <td class="label">Assembler Kmer Value Used</td>
          <td class="value"><xsl:value-of select="//metric/assembler-kmer-used"/></td>
				</tr>
        </xsl:if>
				<tr>
          <td class="label">Genome Size Used</td>
          <td class="value"><xsl:value-of select="//metric/genome-size-used"/></td>
				</tr>
				<tr>
	  <td class="label">Average Insert Size Used</td>
	  <td class="value"><xsl:value-of select="//metric/average-insert-size-used"/></td>
				</tr>
			  </table>
			</td>
      </tr>
      </table>

      <h2 class="report_section">Assembly Statistics</h2>
      <table width="100%" cellspacing="0" cellpadding="0" border="0" class="info_table_group">
      <tr>
			<td>
			  <table width="100%" cellspacing="0" cellpadding="0" border="0" class="info_table">
				<colgroup>
          <col width="30%"/>
          <col width="70%"/>
				</colgroup>
				<tr>
          <td class="label">Reads Attempted</td>
          <td class="value"><xsl:value-of select="//metric/reads-attempted"/></td>
				</tr>
				<tr>
          <td class="label">Reads Processed</td>
          <td class="value"><xsl:value-of select="//metric/reads-processed"/></td>
				</tr>
				<tr>
          <td class="label">Reads Processed Success</td>
          <td class="value"><xsl:value-of select="//metric/reads-processed-success * 100"/><xsl:text>&#37;</xsl:text></td>
				</tr>
				<tr>
          <td class="label">Read Coverage Used</td>
          <td class="value"><xsl:value-of select="//model-info/coverage"/></td>
				</tr>
				<tr>
          <td class="label">Reads Assembled</td>
          <td class="value"><xsl:value-of select="//metric/reads-assembled"/></td>
				</tr>

        <xsl:if test="//metric/reads-assembled='NA'">
	      <tr>
	        <td class="label">Reads Assembled Success</td>
	        <td class="value"><xsl:value-of select="//metric/reads-assembled"/></td>
	      </tr>
	      <tr>
	        <td class="label">Reads Not Assembled (Chaff rate)</td>
	        <td class="value"><xsl:value-of select="//metric/reads-assembled"/></td>
	      </tr>
	      </xsl:if>

        <xsl:if test="//metric/reads-assembled!='NA'">
	      <tr>
	        <td class="label">Reads Assembled Success</td>
          <td class="value"><xsl:value-of select="//metric/reads-assembled-success * 100"/><xsl:text>&#37;</xsl:text></td>
	      </tr>
	      <tr>
	        <td class="label">Reads Not Assembled (Chaff rate)</td>
	        <td class="value"><xsl:value-of select="//metric/reads-not-assembled-pct * 100"/><xsl:text>&#37;</xsl:text></td>
	      </tr>
	      </xsl:if>

			  <tr>
          <td class="label">Average Read Length</td>
          <td class="value"><xsl:value-of select="//metric/average-read-length"/></td>
			  </tr>
			  <tr>
          <td class="label">Assembly Length</td>
          <td class="value"><xsl:value-of select="//metric/assembly-length"/></td>
			  </tr>
			  <tr>
          <td class="label">Contigs</td>
          <td class="value"><xsl:value-of select="//metric/contigs"/></td>
			  </tr>
			  <tr>
          <td class="label">Average Contig Length</td>
          <td class="value"><xsl:value-of select="//metric/average-contig-length"/></td>
			  </tr>

        <xsl:if test="//metric/major-contig-length='300'">
	      <tr>
          <td class="label">Average Major Contig Length (>=300)</td>
          <td class="value"><xsl:value-of select="//metric/average-contig-length-gt-300"/></td>
	      </tr>
	      </xsl:if>

	      <xsl:if test="//metric/major-contig-length='500'">
	      <tr>
          <td class="label">Average Major Contig Length (>=500)</td>
          <td class="value"><xsl:value-of select="//metric/average-contig-length-gt-500"/></td>
	      </tr>
	      </xsl:if>
	  
				<tr>
          <td class="label">n50 Contig Length</td>
          <td class="value"><xsl:value-of select="//metric/n50-contig-length"/></td>
				</tr>

        <xsl:if test="//metric/major-contig-length='300'">
	      <tr>
          <td class="label">n50 Major Contig Length (>=300)</td>
          <td class="value"><xsl:value-of select="//metric/n50-contig-length-gt-300"/></td>
	      </tr>
	      </xsl:if>

	      <xsl:if test="//metric/major-contig-length='500'">
	      <tr>
          <td class="label">n50 Major Contig Length (>=500)</td>
          <td class="value"><xsl:value-of select="//metric/n50-contig-length-gt-500"/></td>
	      </tr>
	      </xsl:if>

				<tr>
          <td class="label">Supercontigs</td>
          <td class="value"><xsl:value-of select="//metric/supercontigs"/></td>
				</tr>
				<tr>
          <td class="label">Average Supercontig Length</td>
          <td class="value"><xsl:value-of select="//metric/average-supercontig-length"/></td>
				</tr>

	  <xsl:if test="//metric/major-contig-length='300'">
	    <tr>
              <td class="label">Average Major Supercontig Length (>=300)</td>
              <td class="value"><xsl:value-of select="//metric/average-supercontig-length-gt-300"/></td>
	    </tr>
	  </xsl:if>

	  <xsl:if test="//metric/major-contig-length='500'">
	    <tr>
              <td class="label">Average Major Supercontig Length (>=500)</td>
              <td class="value"><xsl:value-of select="//metric/average-supercontig-length-gt-500"/></td>
	    </tr>
	  </xsl:if>

				<tr>
          <td class="label">n50 Supercontig Length</td>
          <td class="value"><xsl:value-of select="//metric/n50-supercontig-length"/></td>
				</tr>

	  <xsl:if test="//metric/major-contig-length='300'">
	    <tr>
              <td class="label">n50 Major Supercontig Length (>=300)</td>
              <td class="value"><xsl:value-of select="//metric/n50-supercontig-length-gt-300"/></td>
	    </tr>
	  </xsl:if>

	  <xsl:if test="//metric/major-contig-length='500'">
	    <tr>
              <td class="label">n50 Major Supercontig Length (>=500)</td>
              <td class="value"><xsl:value-of select="//metric/n50-supercontig-length-gt-500"/></td>
	    </tr>
	  </xsl:if>
	  
	  <xsl:if test="//metric/read-depths-ge-5x='NA'">
	    <tr>
	      <td class="label">Read Coverage (>= 5x)</td>
	      <td class="value"><xsl:value-of select="//metric/read-depths-ge-5x"/></td>
	    </tr>
	  </xsl:if>

	  <xsl:if test="//metric/read-depths-ge-5x!='NA'">
	    <tr>
	      <td class="label">Read Coverage (>= 5x)</td>
	      <td class="value"><xsl:value-of select="//metric/read-depths-ge-5x"/><xsl:text>&#37;</xsl:text></td>
	    </tr>
	  </xsl:if>
			  </table>
			</td>
      </tr>
      </table>

      <h2 class="report_section">Report Info</h2>
      <table width="100%" cellspacing="0" cellpadding="0" border="0" class="info_table_group">
      <tr>
			<td>
			  <table width="100%" cellspacing="0" cellpadding="0" border="0" class="info_table">
				<colgroup>
          <col width="30%"/>
          <col width="70%"/>
				</colgroup>
				<tr>
				  <td class="label">Date Generated</td>
          <td class="value"><xsl:value-of select="//report-meta/date"/></td>
				</tr>
				<tr>
          <td class="label">Generator</td>
          <td class="value"><xsl:value-of select="//report-meta/generator"/></td>
				</tr>
			  </table>
			</td>
      </tr>
      </table>
      </div>
    </div>
  </div>
</body>

</html>

  </xsl:template>
</xsl:stylesheet>
