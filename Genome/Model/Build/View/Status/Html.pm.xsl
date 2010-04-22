<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

    <xsl:template match="/">

    <html>
    <head>
    <title>Build <xsl:value-of select="build-status/build/@build-id"/> Status</title>
    <link rel="stylesheet" href="https://gscweb.gsc.wustl.edu/report_resources/apipe_dashboard/css/master.css" type="text/css" media="screen" />
    </head>

    <body>
    <div class="container">
    <div class="background">
    <h1 class="page_title">Build <xsl:value-of select="build-status/build/@build-id"/> Status</h1>
    <div class="page_padding">
    <table width="100%" cellpadding="0" cellspacing="0" border="0">
    <colgroup>
    <col width="50%"/>
    <col width="50%"/>
    </colgroup>
    <tr>
                  <td>
                    <table border="0" cellpadding="0" cellspacing="0" class="info_table">
    <tr><td class="label">Status:</td><td class="value"><xsl:value-of select="build-status/build/@status" /></td></tr>
                      <tr><td class="label">Build:</td><td class="value"><xsl:value-of select="build-status/build/@build-id"/></td></tr>
                      <tr><td class="label">Data Directory:</td><td class="value"><a><xsl:attribute name="href"><xsl:value-of select="build-status/build/@data-directory"/></xsl:attribute>           <xsl:value-of select="build-status/build/@data-directory"/></a></td></tr>
                    </table>
                  </td>
    <td>
    <table border="0" cellpadding="0" cellspacing="0" class="info_table">
    <tr><td class="label">Model ID:</td><td class="value"><xsl:value-of select="build-status/build/@model-id"/></td></tr>
                      <tr><td class="label">Model Name:</td><td class="value"><xsl:value-of select="build-status/build/@model-name"/></td></tr>
                      <tr><td class="label">Processing Profile:</td><td class="value"><xsl:value-of select="build-status/build/stages/@processing_profile"/></td></tr>
                    </table>
                  </td>
    </tr>
              </table>
              <table border="0" cellpadding="0" cellspacing="0" class="stages" width="100%">
    <tr>
                  <xsl:for-each select="build-status/build/stages/stage[count(command_classes/*) > 0]">
    <td>
    <table class="stage" border="0" cellpadding="0" cellspacing="0" width="100%">

    <tr>
                          <th colspan="2">
                            <xsl:variable name="stage_name" select="@value"/>
    <xsl:value-of select="translate($stage_name,'_', ' ')"/>
    </th>
    </tr>

                        <xsl:variable name="num_succeeded" select="count(descendant::*/event_status[text()='Succeeded'])"/>
                        <xsl:variable name="num_succeeded_label">
    <xsl:choose>
    <xsl:when test="$num_succeeded = 0">ghost</xsl:when>
    <xsl:otherwise>label</xsl:otherwise>
    </xsl:choose>
    </xsl:variable>

    <xsl:variable name="num_scheduled" select="count(descendant::*/event_status[text()='Scheduled'])"/>
    <xsl:variable name="num_scheduled_label">
    <xsl:choose>
    <xsl:when test="$num_scheduled = 0">ghost</xsl:when>
    <xsl:otherwise>label</xsl:otherwise>
    </xsl:choose>
    </xsl:variable>

    <xsl:variable name="num_running" select="count(descendant::*/event_status[text()='Running'])"/>
    <xsl:variable name="num_running_label">
    <xsl:choose>
    <xsl:when test="$num_running = 0">ghost</xsl:when>
    <xsl:otherwise>label</xsl:otherwise>
    </xsl:choose>
    </xsl:variable>

    <xsl:variable name="num_abandoned" select="count(descendant::*/event_status[text()='Abandoned'])"/>
    <xsl:variable name="num_abandoned_label">
    <xsl:choose>
    <xsl:when test="$num_abandoned = 0">ghost</xsl:when>
    <xsl:otherwise>label</xsl:otherwise>
    </xsl:choose>
    </xsl:variable>

    <xsl:variable name="num_failed" select="count(descendant::*/event_status[text()='Crashed' or text()='Failed'])"/>
    <xsl:variable name="num_failed_label">
    <xsl:choose>
    <xsl:when test="$num_failed = 0">ghost</xsl:when>
    <xsl:otherwise>label</xsl:otherwise>
    </xsl:choose>
    </xsl:variable>


    <tr><xsl:attribute name="class"><xsl:value-of select="$num_scheduled_label"/></xsl:attribute>
    <td class="label">
  Scheduled:
</td>
    <td class="value">
    <xsl:value-of select="$num_scheduled"/>
    </td>

    </tr>

                        <tr><xsl:attribute name="class"><xsl:value-of select="$num_running_label"/></xsl:attribute>
    <td class="label">
  Running:
</td>
    <td class="value">
    <xsl:value-of select="$num_running"/>
    </td>
    </tr>

                        <tr><xsl:attribute name="class"><xsl:value-of select="$num_succeeded_label"/></xsl:attribute>
    <td class="label">
  Succeeded:
</td>
    <td class="value">
    <xsl:value-of select="$num_succeeded"/>
    </td>
    </tr>

                        <tr><xsl:attribute name="class"><xsl:value-of select="$num_abandoned_label"/></xsl:attribute>
    <td class="label">
  Abandoned:
</td>
    <td class="value">
    <xsl:value-of select="$num_abandoned"/>
    </td>
    </tr>

                        <tr><xsl:attribute name="class"><xsl:value-of select="$num_failed_label"/></xsl:attribute>
    <td class="label">
    Crashed/Failed:
</td>
    <td class="value">
    <xsl:value-of select="$num_failed"/>
    </td>
    </tr>

                        <tr>
                          <td class="label">
  Total:
</td>
    <td class="value">
    <xsl:value-of select="count(descendant::*/event_status)"/>
    </td>
    </tr>
                      </table>
                    </td>
    </xsl:for-each>
    </tr>
              </table>

            <hr/>

    <xsl:for-each select="//stage[count(command_classes/*) > 0 ]">
    <h3>
    <xsl:variable name="stage_name" select="@value"/>
    <xsl:value-of select="translate($stage_name,'_', ' ')"/>
    </h3>
    <table class="alignment_detail" width="100%" cellspacing="0" cellpadding="0" border="0">
    <colgroup>
    <col width="40%"/>
    <col/>
    <col/>
    <col/>
    <col/>
    </colgroup>
    <tr>
                    <th>
                    <xsl:choose><xsl:when test="@value='alignment'">Flow Cell</xsl:when>
    <xsl:otherwise>Event</xsl:otherwise>
    </xsl:choose>
    </th>

    <th>Status</th><th>Scheduled</th><th>Completed</th><th class="last">Elapsed</th>
    </tr>
                <xsl:for-each select="descendant::*/event">
                <tr>
    <td>
    <xsl:choose>
    <xsl:when test="instrument_data_id!=''">
    <xsl:variable name="inst_data_id" select="instrument_data_id" />
    <xsl:for-each select="//instrument_data[@id=$inst_data_id]" >
    <xsl:choose>
    <xsl:when test="gerald_directory">
    <a><xsl:attribute name="href"><xsl:value-of select="gerald_directory"/></xsl:attribute>
    <xsl:value-of select="flow_cell_id"/>
    </a>
    </xsl:when>
    <xsl:otherwise>
    <xsl:value-of select="flow_cell_id"/>
    </xsl:otherwise>
    </xsl:choose>
    </xsl:for-each>
    </xsl:when>
    <xsl:otherwise>
    <xsl:variable name="full_command_class" select="@command_class" />
    <!-- <xsl:value-of select="@command_class"/> -->
    <xsl:value-of select="substring-after($full_command_class,'Genome::Model::Event::Build::')"/>
    </xsl:otherwise>
    </xsl:choose>
    </td>

    <td>
    <xsl:attribute name="class">
    <xsl:text>status </xsl:text><xsl:value-of select="event_status"/>
    </xsl:attribute>
    <a>
    <xsl:attribute name="href">
    <xsl:text>https://gscweb.gsc.wustl.edu/</xsl:text><xsl:value-of select="error_log_file"/>
    </xsl:attribute>
    <xsl:value-of select="event_status"/>
    </a>
    </td>
    <!-- <td><xsl:value-of select="event_status"/></td> -->
    <td><xsl:value-of select="date_scheduled"/></td>
    <td><xsl:value-of select="date_completed"/></td>
    <td class="last"><xsl:value-of select="elapsed_time"/></td>
    </tr>
                </xsl:for-each>
              </table>
    </xsl:for-each>

    </div>
    </div>
    </div>
    </body>
    </html>

    </xsl:template>

</xsl:stylesheet>
