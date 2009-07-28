<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="html"/>
  <xsl:output doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"/>
  <xsl:output doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"/>
  <xsl:template match="/">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
	<head>
		<meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
		<title><xsl:value-of select="//report-meta/description"/></title>
	</head>
	<body style="margin:0;padding:0;">
		<div align="center">
			<table border="0" cellpadding="0" cellspacing="0" width="600" summary="report title and framework">
				<tbody>
					<tr>
						<td>
							<h1 style="font-family:Helvetica,Arial,sans-serif;font-size:105%;line-height:45px;font-weight:bold;color:#FFF;margin:0;padding:0 15px;background-color: #5f604c;border-bottom:5px solid #8dc643">
                <xsl:value-of select="//report-meta/description"/>
							</h1>
						</td>
					</tr>
          <tr>
						<td style="padding:15px 25px;">
              <table border="0" cellspacing="0" cellpadding="0" width="100%" style="margin:20px 0 0 0;padding:0;" summary="report subsection header">
                <tr>
                  <td style="border-bottom: 2px solid #CCC;">
                    <h2 style="font-family:Helvetica,Arial,sans-serif;font-size:100%;color:#36372c;margin:0 0 0 0;padding:5px 0 3px 5px;">
                      Build Scheduled <xsl:value-of select="//model-info/date_scheduled"/>
                    </h2>
                  </td>
                </tr>
              </table>
              <table border="0" cellspacing="0" cellpadding="0" width="100%" summary="report section header">
								<tbody>
									<tr>
										<td style="padding:10px;" colspan="2">
											<table border="0" cellspacing="0" cellpadding="0" width="100%" style="margin:5px 0 5px 5px;padding:0;" summary="report key value data table">
												<colgroup>
													<col/>
													<col width="100%"/>
												</colgroup>
												<tr>
													<td style="font-family:Helvetica,Arial,sans-serif;font-size:90%;color:#36372c;font-weight:bold;text-align:left;white-space:nowrap;padding:5px 5px 5px 0;">
                            Status: 
													</td>
													<td style="font-family:Helvetica,Arial,sans-serif;font-size:90%;color:#36372c;white-space:nowrap;padding:5px 5px 5px 0;">
                            <a>
                              <xsl:attribute name="href">https://lims.gsc.wustl.edu/cgi-bin/apipe/status.cgi?build-id<xsl:value-of select="//model-info/build-id"/></xsl:attribute>
                              https://lims.gsc.wustl.edu/cgi-bin/apipe/status.cgi?build-id<xsl:value-of select="//model-info/build-id"/>
                            </a>
													</td>
                        </tr>
												<tr>
													<td style="font-family:Helvetica,Arial,sans-serif;font-size:90%;color:#36372c;font-weight:bold;text-align:left;white-space:nowrap;padding:5px 5px 5px 0;">
                            Build Id:
													</td>
													<td style="font-family:Helvetica,Arial,sans-serif;font-size:90%;color:#36372c;white-space:nowrap;padding:5px 5px 5px 0;">
                            <xsl:value-of select="//model-info/build-id"/>
													</td>
												</tr>
												<tr>
													<td style="font-family:Helvetica,Arial,sans-serif;font-size:90%;color:#36372c;font-weight:bold;text-align:left;white-space:nowrap;padding:5px 5px 5px 0;">
                            Data Directory:
													</td>
													<td style="font-family:Helvetica,Arial,sans-serif;font-size:90%;color:#36372c;white-space:nowrap;padding:5px 5px 5px 0;">
                            <a><xsl:attribute name="href">https://<xsl:value-of select="//model-info/data-directory"/></xsl:attribute><xsl:value-of select="//model-info/data-directory"/></a>
													</td>
												</tr>
                      </table>
                    </td>
                  </tr>
                </tbody>
              </table>
            </td>
          </tr>
					<tr>
						<td style="padding:15px 25px;">
              <table border="0" cellspacing="0" cellpadding="0" width="100%" style="margin:20px 0 0 0;padding:0;" summary="report subsection header">
                <tr>
                  <td style="border-bottom: 2px solid #CCC;">
                    <h2 style="font-family:Helvetica,Arial,sans-serif;font-size:100%;color:#36372c;margin:0 0 0 0;padding:5px 0 3px 5px;">
                      Model
                    </h2>
                  </td>
                </tr>
              </table>
							<!-- report section -->
							<table border="0" cellspacing="0" cellpadding="0" width="100%" summary="report section header">
								<tbody>
									<tr>
										<td style="padding:10px;" colspan="2">
											<!-- report subsection-->

											<table border="0" cellspacing="0" cellpadding="0" width="100%" style="margin:5px 0 5px 5px;padding:0;" summary="report key value data table">
												<colgroup>
													<col/>
													<col width="100%"/>
												</colgroup>
												<tr>
													<td style="font-family:Helvetica,Arial,sans-serif;font-size:90%;color:#36372c;font-weight:bold;text-align:left;white-space:nowrap;padding:5px 5px 5px 0;">
                            Model Id: 
													</td>
													<td style="font-family:Helvetica,Arial,sans-serif;font-size:90%;color:#36372c;white-space:nowrap;padding:5px 5px 5px 0;">
                            <xsl:value-of select="//model-info/id"/>
                          </td>
												</tr>
												<tr>
													<td style="font-family:Helvetica,Arial,sans-serif;font-size:90%;color:#36372c;font-weight:bold;text-align:left;white-space:nowrap;padding:5px 5px 5px 0;">
                            Model Name: 
													</td>
													<td style="font-family:Helvetica,Arial,sans-serif;font-size:90%;color:#36372c;white-space:nowrap;padding:5px 5px 5px 0;">
                            <xsl:value-of select="//model-info/name"/>
                          </td>
												</tr>
												<tr>
													<td style="font-family:Helvetica,Arial,sans-serif;font-size:90%;color:#36372c;font-weight:bold;text-align:left;white-space:nowrap;padding:5px 5px 5px 0;">
                            Processing Profile Name: 
													</td>
													<td style="font-family:Helvetica,Arial,sans-serif;font-size:90%;color:#36372c;white-space:nowrap;padding:5px 5px 5px 0;">
                            <xsl:value-of select="//model-info/processing-profile-name"/>
                          </td>
												</tr>
												<tr>
													<td style="font-family:Helvetica,Arial,sans-serif;font-size:90%;color:#36372c;font-weight:bold;text-align:left;white-space:nowrap;padding:5px 5px 5px 0;">
                            Subject Name: 
													</td>
													<td style="font-family:Helvetica,Arial,sans-serif;font-size:90%;color:#36372c;white-space:nowrap;padding:5px 5px 5px 0;">
                            <xsl:value-of select="//model-info/subject-name"/>
                          </td>
												</tr>
												<tr>
													<td style="font-family:Helvetica,Arial,sans-serif;font-size:90%;color:#36372c;font-weight:bold;text-align:left;white-space:nowrap;padding:5px 5px 5px 0;">
                            Subject Type: 
													</td>
													<td style="font-family:Helvetica,Arial,sans-serif;font-size:90%;color:#36372c;white-space:nowrap;padding:5px 5px 5px 0;">
                            <xsl:value-of select="//model-info/subject-type"/>
                          </td>
												</tr>
											</table>
										</td>
									</tr>
								</tbody>
							</table>
						</td>
					</tr>
					<tr>
						<td align="right" style="background-color: #f2f2f1;">
							<img src="cid:footerimg" width="106" height="50" alt="The Genome Center at Washington University" style="margin: 10px;" />
						</td>
					</tr>
				</tbody>
			</table>
		</div>
	</body>
</html>
  </xsl:template>
</xsl:stylesheet>
