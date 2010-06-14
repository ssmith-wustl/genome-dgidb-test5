<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">


  <xsl:template name="genome_model_build" match="build-status">
        <script type="text/javascript">
          <![CDATA[
              $(document).ready(function() {
                  $("#alignment").tablesorter({
                      // sort on first column, ascending
                      sortList: [[0,0]]
                  });
              });
          ]]>
        </script>
        <script type='text/javascript' src='/res/old/report_resources/jquery/boxy/src/javascripts/jquery.boxy.js'></script>
        <link rel="stylesheet" href="/res/old/report_resources/jquery/boxy/src/stylesheets/boxy.css" type="text/css" />
        <script type="text/javascript">
          <![CDATA[
                   function event_popup(eventObject) {
                   // assemble event info into a table
                   var popup_content = '<table class="boxy_info" cellpadding="0" cellspacing="0" border="0"><tbody>';
                   for (prop in eventObject) {
                   if (prop != 'popup_title') {
                   popup_content += '<tr><td class="label">' + prop.replace(/_/g," ") + ':</td><td class="value">' + eventObject[prop] + '</td></tr>';
                   }
                   }

popup_content += '</tbody></table>';

// create popup
var popup = new Boxy(popup_content, {title:eventObject.popup_title, fixed:false});
popup.center();
}
          ]]>
        </script>
              <h2 class="page_title build_icon">Build <xsl:value-of select="build/@build-id"/> Status</h2>
              <table cellpadding="0" cellspacing="0" border="0" class="info_table_group">
                <tr>
                  <xsl:variable name="status" select="//build/@status"/>
                  <td>
                    <table border="0" cellpadding="0" cellspacing="0" class="info_table" width="100%">
                      <tr><td class="label">Model ID:</td><td class="value"><xsl:for-each select="build/model"><xsl:call-template name="object_link"><xsl:with-param name="linktext"><xsl:value-of select="./@id"/></xsl:with-param></xsl:call-template></xsl:for-each></td></tr>
                      <tr><td class="label">Model Name:</td><td class="value"><xsl:value-of select="build/@model-name"/></td></tr>
                      <xsl:if test="build/@common-name">
                        <tr><td class="label">Common Name:</td><td class="value"><xsl:value-of select="build/@common-name"/></td></tr>
                      </xsl:if>
                      <xsl:if test="build/@base-alignment-path">
                          <tr><td class="label">Base Alignment Path:</td><td class="value">
                                <a><xsl:attribute name="href"><xsl:text>https://gscweb.gsc.wustl.edu/</xsl:text><xsl:value-of select="build/@base-alignment-path"/></xsl:attribute><xsl:attribute name="class"><xsl:text>grey</xsl:text></xsl:attribute><xsl:text>(base alignment path)</xsl:text></a>
                          </td></tr>
                      </xsl:if>
                      <tr><td class="label">LSF Job ID:</td><td class="value"><xsl:value-of select="build/@lsf-job-id"/></td></tr>
                      <tr><td class="label">Workflow Instance ID:</td><td class="value"><xsl:for-each select="build/workflow"><xsl:call-template name="object_link">
                            <xsl:with-param name="linktext"><xsl:value-of select="./@id"/></xsl:with-param>
                          </xsl:call-template></xsl:for-each>
                      <xsl:if test="//build/workflow/@instance-status">
                        <xsl:if test="$status = 'Running'">
                          <xsl:text> (</xsl:text>
                          <xsl:value-of select="build/workflow/@instance-status"/><xsl:text>)</xsl:text>
                        </xsl:if>
                      </xsl:if>
                      </td></tr>
                    </table>
                  </td>
                  <td>
                    <table border="0" cellpadding="0" cellspacing="0" class="info_table" width="100%">
                      <tr><td class="label">Status:</td><td class="value"><xsl:value-of select="build/@status" />
                      <xsl:if test="$status = 'Succeeded'">
                        <xsl:text> </xsl:text><a><xsl:attribute name="href"><xsl:text>https://gscweb.gsc.wustl.edu/</xsl:text><xsl:value-of select="build/@data-directory"/><xsl:text>/reports/Summary/report.html</xsl:text></xsl:attribute><xsl:attribute name="class"><xsl:text>grey</xsl:text></xsl:attribute><xsl:text>(view build summary report)</xsl:text></a>
                      </xsl:if>

                      </td></tr>
                      <tr><td class="label">Processing Profile:</td><td class="value"><xsl:value-of select="build/stages/@processing_profile"/> (<xsl:value-of select="build/stages/@processing_profile_type"/>)</td></tr>
                      <tr><td class="label">Data Directory:</td><td class="value"><a><xsl:attribute name="href"><xsl:text>https://gscweb.gsc.wustl.edu/</xsl:text><xsl:value-of select="build/@data-directory"/></xsl:attribute><xsl:value-of select="build/@data-directory"/></a></td></tr>
                      <tr><td class="label">Software Revision:</td><td class="value"><xsl:value-of select="build/@software-revision"/></td></tr>
                      <xsl:if test="//build/@kilobytes-requested">
                        <tr>
                          <xsl:variable name="kb_requested" select="//build/@kilobytes-requested"/>
                          <td class="label">Disk Space (kbytes):</td>
                          <td class="value"><xsl:value-of select="format-number($kb_requested, '#,##0')"/></td>
                        </tr>
                      </xsl:if>
                      <xsl:if test="build/@error-log">
                        <tr><td class="label">Error File:</td><td class="value"><a><xsl:attribute name="href"><xsl:text>https://gscweb.gsc.wustl.edu/</xsl:text><xsl:value-of select="build/@error-log"/></xsl:attribute>
                        <xsl:call-template name="substring-after-last">
                          <xsl:with-param name="input" select="build/@error-log"/>
                          <xsl:with-param name="substr" select="'/'"/>
                        </xsl:call-template>
                      </a></td>
                        </tr>
                      </xsl:if>
                    </table>
                  </td>
                </tr>
              </table>
              
              <xsl:if test="count(//build/aspect[@name='inputs']/object) > 0 ">
			    <xsl:for-each select="//build/aspect[@name='inputs']">
			      <xsl:call-template name="genome_model_input_table"/>
			    </xsl:for-each>
			  </xsl:if>
			  
			  <xsl:if test="count(//links/aspect[@name='to_builds']/object | //links/aspect[@name='from_builds']/object) > 0">
                <xsl:for-each select="//links">
                  <xsl:call-template name="genome_model_link_table"/>
                </xsl:for-each>
              </xsl:if>
			  
              <br/>
              View: <a href="#show_events" id="show_events">Events</a> | <a href="#show_workflow" id="show_workflow">Workflow</a>
              <script type="text/javascript">
                <![CDATA[
                  $(document).ready(function() {
                    $('#show_events').click(function() {
                      $('#workflowview').hide();
                      $('#eventview').show();
                      return false;
                    });

                    $('#show_workflow').click(function() {
                      $('#eventview').hide();
                      if ($('#workflowview').length == 0) {
                          $('.viewport').append('<div id="workflowview"/>');

                          $('#workflowview').load('/view/workflow/operation/instance/statuspopup.html?id=]]><xsl:value-of select="//build/workflow/@id"/><![CDATA[');
                      } 
                      $('#workflowview').show();
                      return false;
                    });
                  });
                ]]>
              </script>
              <div class="viewport">
              <div id="eventview">
              <table border="0" cellpadding="0" cellspacing="0" class="stages" width="100%">
                <tr>
                  <xsl:for-each select="build/stages/stage[count(command_classes/*) > 0]">
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

                        <tr class="total">
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
                <h2>
                  <xsl:variable name="stage_name" select="@value"/>
                  <xsl:value-of select="translate($stage_name,'_', ' ')"/>
                </h2>
                <table class="list tablesorter" width="100%" cellspacing="0" cellpadding="0" border="0">
                  <xsl:attribute name="id"><xsl:value-of select="@value"/></xsl:attribute>
                  <colgroup>
                    <col width="40%"/>
                    <col/>
                    <col/>
                    <col/>
                    <col/>
                  </colgroup>
                  <thead>
                    <tr>
                      <th>
                        <xsl:choose><xsl:when test="@value='alignment'">flow cell</xsl:when>
                        <xsl:otherwise>event</xsl:otherwise>
                        </xsl:choose>
                      </th>

                      <th>status</th><th>scheduled</th><th>completed</th><th class="last">elapsed</th>
                    </tr>
                  </thead>
                  <tbody>
                    <xsl:for-each select="descendant::*/event">
                      <tr onmouseover="this.className = 'hover'" onmouseout="this.className=''">
                        <xsl:attribute name="onclick">
                          <!-- assemble eventObject to be passed to popup function -->
                          <!-- this is a crazy javascript/xsl kludge and I'm sorry to anyone who has to decipher this. Basically, it's creating a  javascript object that the event_popup will convert into a table. XSL couldn't deal with the anchor elements raw, so they needed to be URL encoded. Hence the mess. There's probably a better way to do this. Sorry. -->
                          <xsl:text>javascript:event_popup({</xsl:text>
                          <!-- add event id -->
                          <xsl:text>event_id:"</xsl:text><xsl:value-of select="@id"/><xsl:text>",</xsl:text>

                          <xsl:for-each select="child::*">
                            <xsl:choose>
                              <!-- handle output and error log file nodes -->
                              <xsl:when test="contains(local-name(),'_file')">
                                <xsl:value-of select="local-name()"/><xsl:text>:"</xsl:text>
                                <xsl:text>&lt;a href=\"http://gscweb</xsl:text><xsl:value-of select="current()"/><xsl:text>\"&gt;</xsl:text>
                                <xsl:call-template name="substring-after-last">
                                  <xsl:with-param name="input" select="current()"/>
                                  <xsl:with-param name="substr" select="'/'"/>
                                </xsl:call-template>


                                <xsl:text>&lt;/a&gt;</xsl:text>
                                <xsl:text>",</xsl:text>
                              </xsl:when>

                              <!-- handle alignment_directory node(s) -->
                              <xsl:when test="contains(local-name(),'alignment_directory')">
                                <xsl:choose>
                                  <xsl:when test="starts-with(current(), '/')">
                                    <!-- starts with a /, so most likely is a directory string -->
                                    <xsl:value-of select="local-name()"/><xsl:text>:"</xsl:text>
                                    <xsl:text>&lt;a href=\"http://gscweb</xsl:text><xsl:value-of select="current()"/><xsl:text>\"&gt;</xsl:text>
                                    <xsl:call-template name="substring-after-last">
                                      <xsl:with-param name="input" select="current()"/>
                                      <xsl:with-param name="substr" select="'/'"/>
                                    </xsl:call-template>


                                    <xsl:text>&lt;/a&gt;</xsl:text>
                                    <xsl:text>",</xsl:text>
                                  </xsl:when>
                                  <xsl:otherwise>
                                    <!-- doesn't start with a /, so probably is a message of some kind -->
                                    <xsl:value-of select="local-name()"/><xsl:text>:"</xsl:text>
                                    <xsl:value-of select="normalize-space(current())"/><xsl:text>",</xsl:text>
                                  </xsl:otherwise>
                                </xsl:choose>
                              </xsl:when>

                              <xsl:otherwise>
                                <xsl:value-of select="local-name()"/><xsl:text>:"</xsl:text><xsl:value-of select="current()"/><xsl:text>",</xsl:text>
                              </xsl:otherwise>
                            </xsl:choose>
                          </xsl:for-each>
                          <!-- see if we have any instrument data and append that to the event object if we do -->
                          <xsl:if test="instrument_data_id!=''">
                            <xsl:variable name="inst_data_id" select="instrument_data_id" />
                            <xsl:for-each select="//instrument_data[@id=$inst_data_id]/*" >
                              <xsl:choose>
                                <xsl:when test="local-name() != 'gerald_directory' and local-name() != 'lane'">
                                  <xsl:value-of select="local-name()"/><xsl:text>:"</xsl:text><xsl:value-of select="current()"/><xsl:text>",</xsl:text>
                                </xsl:when>
                              </xsl:choose>
                            </xsl:for-each>
                          </xsl:if>

                          <!-- assemble popup title -->
                          <xsl:variable name="evt_command_class" select="@command_class" />

                          <xsl:text>popup_title:"</xsl:text><xsl:value-of select="substring-after($evt_command_class,'Genome::Model::Build::Command::')"/><xsl:value-of select="substring-after($evt_command_class,'Genome::Model::Event::Build::')"/><xsl:text> #</xsl:text><xsl:value-of select="@id"/><xsl:text>"</xsl:text>
                          <!-- and finish off the object  -->
                          <xsl:text>});</xsl:text>
                        </xsl:attribute>
                        <td>
                          <xsl:variable name="command_class" select="@command_class"/>
                          <xsl:variable name="containing_command_class" select="../../@value"/>
                          <xsl:choose>
                            <!-- if command_class contains 'AlignReads' there should be instrument data associated -->
                            <xsl:when test="contains($command_class, 'AlignReads') or contains($containing_command_class, 'AlignReads')">
                              <xsl:variable name="inst_data_id" select="instrument_data_id" />
                              <xsl:variable name="inst_data_count" select="count(//instrument_data[@id=$inst_data_id])"/>                              <xsl:choose>
                              <!-- if we have instrument data element(s), show flow cell and lane -->
                              <xsl:when test="$inst_data_count > 0">
                                <xsl:for-each select="//instrument_data[@id=$inst_data_id]" >
                                  <xsl:value-of select="flow_cell_id"/><xsl:text> Lane: </xsl:text><xsl:value-of select="lane"/>
                                </xsl:for-each>
                                <xsl:if test="filter_desc"><xsl:text> </xsl:text>(<xsl:value-of select="filter_desc"/>)</xsl:if>
                              </xsl:when>
                              <xsl:otherwise>
                                <!-- no instrument data elements, show a warning message -->
                                <span style="color: #933; font-weight: bold;">No instrument data found for this lane.</span>
                              </xsl:otherwise>
                            </xsl:choose>
                            </xsl:when>
                            <xsl:otherwise>
                              <!-- event is not expected to have instrument data, so show command class -->
                              <xsl:variable name="full_command_class" select="@command_class" />
                              <xsl:value-of select="substring-after($full_command_class,'Genome::Model::Build::Command::')"/>
                              <xsl:value-of select="substring-after($full_command_class,'Genome::Model::Event::Build::')"/>
                            </xsl:otherwise>
                          </xsl:choose>
                        </td>
                        <td>
                          <xsl:variable name="e_status" select="event_status"/>
                          <xsl:variable name="lc_e_status" select="translate($e_status,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz')"/>
                          <xsl:attribute name="class"><xsl:text>status </xsl:text><xsl:value-of select="$lc_e_status"/></xsl:attribute>
                          <xsl:value-of select="$lc_e_status"/>
                        </td>
                        <!-- <td><xsl:value-of select="event_status"/></td> -->
                        <td><xsl:value-of select="date_scheduled"/></td>
                        <td><xsl:value-of select="date_completed"/></td>
                        <td class="last"><xsl:value-of select="elapsed_time"/></td>
                      </tr>
                    </xsl:for-each>
                  </tbody>
                </table>
              </xsl:for-each>
              </div>
              </div>
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
