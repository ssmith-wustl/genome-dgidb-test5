<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">


  <xsl:template name="genome_model_build" match="build-status">
    <!-- global object for data, uses YUI Module Pattern -->
    <script type="text/javascript">
      window.page_data = function(){
      return {
      workflow: {
      "id": <xsl:value-of select="//build/workflow/@id"/>
      },
      stages: {
      "count": <xsl:value-of select="count(build/stages/stage)"/>
      }
      }
      }();
    </script>

    <script type="text/javascript" src="/res/js/pkg/json2.js"></script>
    <link rel="stylesheet" href="/res/css/legacy.css" type="text/css" media="screen, projection"/>

    <script type='text/javascript' src='/res/js/pkg/boxy/javascripts/jquery.boxy.js'></script>
    <link rel="stylesheet" href="/res/js/pkg/boxy/stylesheets/boxy.css" type="text/css" />

    <script type='text/javascript' src='/res/js/app/genome_model_build.js'></script>

    <xsl:call-template name="view_header">
      <xsl:with-param name="label_name" select="'Build:'" />
      <xsl:with-param name="display_name" select="build/@build-id" />
      <xsl:with-param name="icon" select="'genome_model_build_32'" />
    </xsl:call-template>

    <div class="content rounded shadow">
      <div class="container">
        <div id="objects" class="span-24 last">
          <xsl:call-template name="genome_model_build_attributes_box"/>

          <xsl:call-template name="genome_model_build_attributes_box2"/>

        </div>

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

        <div id="process_tabs" class="span-24 last">
          <ul>
            <li class="tab_header"><h3 class="genome_processingprofile_16">Build Process</h3></li>
            <li><a><xsl:attribute name="href">/view/workflow/operation/instance/statuspopup.html?id=<xsl:value-of select="//build/workflow/@id"/></xsl:attribute><span class="spinner"><xsl:text> </xsl:text></span>workflow</a></li>

            <li><a href="#events">events</a></li>
          </ul>

          <div id="events">
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
                <table class="lister" width="100%" cellspacing="0" cellpadding="0" border="0">
                  <xsl:attribute name="id"><xsl:value-of select="@value"/></xsl:attribute>
                  <colgroup>
                    <col width="40%"/>
                    <col/>
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

                      <th>status</th>
                      <th>scheduled</th>
                      <th>completed</th>
                      <th class="last">elapsed</th>
                      <th><br/></th>
                    </tr>
                  </thead>
                  <tbody>
                    <xsl:for-each select="descendant::*/event">
                      <tr>
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
                                  <xsl:value-of select="flow_cell_id"/><xsl:text disable-output-escaping="yes"> Lane: </xsl:text><xsl:value-of select="lane"/>
                                </xsl:for-each>
                                <xsl:if test="filter_desc"><xsl:text disable-output-escaping="yes"> </xsl:text>(<xsl:value-of select="filter_desc"/>)</xsl:if>
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
                          <xsl:attribute name="class"><xsl:text disable-output-escaping="yes">status </xsl:text><xsl:value-of select="$lc_e_status"/></xsl:attribute>
                          <xsl:value-of select="$lc_e_status"/>
                        </td>
                        <!-- <td><xsl:value-of select="event_status"/></td> -->
                        <td><xsl:value-of select="date_scheduled"/></td>
                        <td><xsl:value-of select="date_completed"/></td>
                        <td class="last"><xsl:value-of select="elapsed_time"/></td>
                        <td class="buttons">
                          <script type="text/javascript">

                            window.obj<xsl:value-of select="@id"/> = {
                            event_id: <xsl:value-of select="@id"/>,
                            <xsl:for-each select="child::*">
                              <xsl:choose>
                                <!-- handle output and error log file nodes -->
                                <xsl:when test="contains(local-name(),'_file')">
                                  <xsl:value-of select="local-name()"/><xsl:text disable-output-escaping="yes">:"</xsl:text>
                                  <xsl:text disable-output-escaping="yes">&lt;a href=\"http://gscweb</xsl:text><xsl:value-of select="current()"/><xsl:text disable-output-escaping="yes">\"&gt;</xsl:text>
                                  <xsl:call-template name="substring-after-last">
                                    <xsl:with-param name="input" select="current()"/>
                                    <xsl:with-param name="substr" select="'/'"/>
                                  </xsl:call-template>


                                  <xsl:text disable-output-escaping="yes">&lt;/a&gt;</xsl:text>
                                  <xsl:text disable-output-escaping="yes">",</xsl:text>
                                </xsl:when>

                                <!-- handle alignment_directory node(s) -->
                                <xsl:when test="contains(local-name(),'alignment_directory')">
                                  <xsl:choose>
                                    <xsl:when test="starts-with(current(), '/')">
                                      <!-- starts with a /, so most likely is a directory string -->
                                      <xsl:value-of select="local-name()"/><xsl:text disable-output-escaping="yes">:"</xsl:text>
                                      <xsl:text disable-output-escaping="yes">&lt;a href=\"http://gscweb</xsl:text><xsl:value-of select="current()"/><xsl:text disable-output-escaping="yes">\"&gt;</xsl:text>
                                      <xsl:call-template name="substring-after-last">
                                        <xsl:with-param name="input" select="current()"/>
                                        <xsl:with-param name="substr" select="'/'"/>
                                      </xsl:call-template>


                                      <xsl:text disable-output-escaping="yes">&lt;/a&gt;</xsl:text>
                                      <xsl:text disable-output-escaping="yes">",</xsl:text>
                                    </xsl:when>
                                    <xsl:otherwise>
                                      <!-- doesn't start with a /, so probably is a message of some kind -->
                                      <xsl:value-of select="local-name()"/><xsl:text disable-output-escaping="yes">:"</xsl:text>
                                      <xsl:value-of select="normalize-space(current())"/><xsl:text disable-output-escaping="yes">",</xsl:text>
                                    </xsl:otherwise>
                                  </xsl:choose>
                                </xsl:when>

                                <xsl:otherwise>
                                  <xsl:value-of select="local-name()"/><xsl:text disable-output-escaping="yes">:"</xsl:text><xsl:value-of select="current()"/><xsl:text disable-output-escaping="yes">",</xsl:text>
                                </xsl:otherwise>
                              </xsl:choose>
                            </xsl:for-each>
                            <!-- see if we have any instrument data and append that to the event object if we do -->
                            <xsl:if test="instrument_data_id!=''">
                              <xsl:variable name="inst_data_id" select="instrument_data_id" />
                              <xsl:for-each select="//instrument_data[@id=$inst_data_id]/*" >
                                <xsl:choose>
                                  <xsl:when test="local-name() != 'gerald_directory' and local-name() != 'lane'">
                                    <xsl:value-of select="local-name()"/><xsl:text disable-output-escaping="yes">:"</xsl:text><xsl:value-of select="current()"/><xsl:text disable-output-escaping="yes">",</xsl:text>
                                  </xsl:when>
                                </xsl:choose>
                              </xsl:for-each>
                            </xsl:if>

                            <!-- assemble popup title -->
                            <xsl:variable name="evt_command_class" select="@command_class" />

                            <xsl:text disable-output-escaping="yes">popup_title:"</xsl:text><xsl:value-of select="substring-after($evt_command_class,'Genome::Model::Build::Command::')"/><xsl:value-of select="substring-after($evt_command_class,'Genome::Model::Event::Build::')"/><xsl:text disable-output-escaping="yes"> #</xsl:text><xsl:value-of select="@id"/><xsl:text disable-output-escaping="yes">"</xsl:text>
                            };
                            <!--   event_status: "", -->
                            <!--   lsf_job_id: "7872441", -->
                            <!--   lsf_job_status: "UNAVAILABLE", -->
                            <!--   date_scheduled: "2009-12-17 09:10:13", -->
                            <!--   date_completed: "2010-01-21 14:09:18", -->
                            <!--   elapsed_time: "35:04:59:05", -->
                            <!--   instrument_data_id: "", -->
                            <!--   output_log_file: "<a href=\"http://gscweb/gscmnt/sata400/info/dlarson/BRC10/somatic_pipeline/BRC10-somatic-v1/build100513550/logs//100513583.out\">100513583.out</a>", -->
                            <!--   error_log_file: "<a href=\"http://gscweb/gscmnt/sata400/info/dlarson/BRC10/somatic_pipeline/BRC10-somatic-v1/build100513550/logs//100513583.err\">100513583.err</a>", -->
                            <!--   popup_title: "Somatic::RunWorkflow #100513583" -->
                            <!-- }; -->


                          </script>
                          <a class="mini btn">
                            <xsl:attribute name="href">
                              javascript:event_popup(window.obj<xsl:value-of select="@id"/>);
                            </xsl:attribute>
                          <span class="sm-icon sm-icon-newwin"><br/></span>event details</a>
                        </td>
                      </tr>
                    </xsl:for-each>
                  </tbody>
                </table>
              </xsl:for-each>
            </div> <!-- end .events -->
          </div>

        </div>
      </div> <!-- end container -->
    </div> <!-- end content -->

    <xsl:call-template name="footer">
      <xsl:with-param name="footer_text">
        <br/>
      </xsl:with-param>
    </xsl:call-template>

  </xsl:template>

  <xsl:template name="genome_model_build_attributes_box">
    <xsl:variable name="build_directory_url">
      <xsl:text>https://gscweb.gsc.wustl.edu/</xsl:text><xsl:value-of select="normalize-space(aspect[@name='data_directory']/value)" />
    </xsl:variable>

    <xsl:variable name="summary_report_url">
      <xsl:value-of select="$build_directory_url"/><xsl:text>/reports/Summary/report.html</xsl:text>
    </xsl:variable>

    <xsl:variable name="status" select="build/@status"/>

    <xsl:comment>template: genome_model_build.xsl:genome_model_build_attributes_box</xsl:comment>
    <!-- details for this model -->
    <div class="span_8_box_masonry">
      <div class="box_header rounded-top span-8 last">
        <div class="box_title"><h3 class="nontyped span-7 last">Build Attributes</h3></div>
        <div class="box_button">

        </div>
      </div>

      <div class="box_content rounded-bottom span-8 last">
        <table class="name-value">
          <tbody>
            <tr>
              <td class="name">status:
              </td>
              <td class="value">
                <xsl:value-of select="$status" />
              </td>
            </tr>

            <xsl:if test="$status = 'Succeeded'">
              <tr>
                <td class="name"><br/></td>
                <td class="value">
                  <a class="mini btn"><xsl:attribute name="href">
                    <xsl:text>https://gscweb.gsc.wustl.edu/</xsl:text><xsl:value-of select="build/@summary-report"/></xsl:attribute><span class="sm-icon sm-icon-extlink"><br/></span><xsl:text>summary report</xsl:text>
                  </a>
                </td>
              </tr>
            </xsl:if>

            <tr>
              <td class="name"><br/>
              </td>
              <td class="value">
                <a class="mini btn"><xsl:attribute name="href">
                  <xsl:text>https://gscweb.gsc.wustl.edu/</xsl:text><xsl:value-of select="build/@data-directory"/></xsl:attribute><span class="sm-icon sm-icon-extlink"><br/></span><xsl:text>data directory</xsl:text>
                </a>
              </td>
            </tr>

            <tr>
              <td class="name"><br/>
              </td>
              <td class="value">
                <a class="mini btn"><xsl:attribute name="href"><xsl:text>https://gscweb.gsc.wustl.edu/</xsl:text><xsl:value-of select="build/@error-log"/></xsl:attribute>
                <span class="sm-icon sm-icon-extlink"><br/></span><xsl:text>error log</xsl:text>
                </a>
              </td>
            </tr>

            <tr>
              <td class="name">model:
              </td>
              <td class="value">
                <xsl:value-of select="build/@model-name"/>
              </td>
            </tr>

            <tr>
              <td class="name"><br/></td>
              <td class="value">
                <xsl:for-each select="build/model">
                  <xsl:call-template name="object_link_button">
                    <xsl:with-param name="linktext">
                      <xsl:value-of select="./@id"/>
                    </xsl:with-param>
                    <xsl:with-param name="icon" select="'sm-icon-extlink'" />
                  </xsl:call-template>
                </xsl:for-each>
              </td>
            </tr>

          </tbody>
        </table>
      </div>
    </div>

  </xsl:template>

  <xsl:template name="genome_model_build_attributes_box2">
    <xsl:variable name="build_directory_url">
      <xsl:text>https://gscweb.gsc.wustl.edu/</xsl:text><xsl:value-of select="normalize-space(aspect[@name='data_directory']/value)" />
    </xsl:variable>

    <xsl:variable name="summary_report_url">
      <xsl:value-of select="$build_directory_url"/><xsl:text>/reports/Summary/report.html</xsl:text>
    </xsl:variable>

    <xsl:variable name="status" select="build/@status"/>

    <xsl:comment>template: genome_model_build.xsl:genome_model_build_attributes_box2</xsl:comment>
    <!-- details for this model -->
    <div class="span_8_box_masonry">
      <div class="box_header rounded-top span-8 last">
        <div class="box_title"><h3 class="nontyped span-7 last"><br/></h3></div>
        <div class="box_button">

        </div>
      </div>

      <div class="box_content rounded-bottom span-8 last">
        <table class="name-value">
          <tbody>

            <tr>
              <td class="name">LSF job id:
              </td>
              <td class="value">
                <xsl:value-of select="build/@lsf-job-id"/>
              </td>
            </tr>

            <tr>
              <td class="name">workflow instance id:
              </td>
              <td class="value">
                <xsl:for-each select="build/workflow">
                  <xsl:call-template name="object_link_button">
                    <xsl:with-param name="linktext">
                      <xsl:value-of select="./@id"/>
                    </xsl:with-param>
                    <xsl:with-param name="icon" select="'sm-icon-extlink'" />
                  </xsl:call-template>
                </xsl:for-each>

              </td>
            </tr>

            <xsl:choose>
              <xsl:when test="build/@common-name">
                <tr>
                  <td class="name">common name:</td>
                  <td class="value">
                    <xsl:value-of select="build/@common-name"/>
                  </td>
                </tr>
              </xsl:when>
              <xsl:otherwise>
                <tr>
                  <td class="name">common name:</td>
                  <td class="value">
                    --
                  </td>
                </tr>
              </xsl:otherwise>
            </xsl:choose>

            <tr>
              <td class="name">processing profile:</td>
              <td class="value">
                <xsl:value-of select="build/stages/@processing_profile"/> (<xsl:value-of select="build/stages/@processing_profile_type"/>)
              </td>
            </tr>

            <xsl:choose>
              <xsl:when test="build/@software-revision">
                <tr>
                  <td class="name">software revision:</td>
                  <td class="value">
                    <xsl:value-of select="build/@software-revision"/>
                  </td>
                </tr>
              </xsl:when>
              <xsl:otherwise>
                <tr>
                  <td class="name">software revision:</td>
                  <td class="value">
                    --
                  </td>
                </tr>
              </xsl:otherwise>
            </xsl:choose>

            <tr>
              <td class="name">kB requested:</td>
              <td class="value">
                <xsl:variable name="kb_requested" select="//build/@kilobytes-requested"/>
                <xsl:value-of select="format-number($kb_requested, '#,##0')"/>
              </td>
            </tr>


          </tbody>
        </table>
      </div>
    </div>

  </xsl:template>


  <!-- initializes the dataTable plugin for model set views -->
  <xsl:template name="genome_model_build_set_table_init" match="object[./types[./isa[@type='Genome::Model::Build']]]" mode="set_table_init">
    <xsl:comment>template: status/genome_model_build.xsl match: object[./types[./isa[@type='Genome::Model::Build']]] mode: set_table_init</xsl:comment>
    <script type="text/javascript">
      <xsl:text disable-output-escaping="yes">
        <![CDATA[
                 $(document).ready(
                 window.setTable = $('#set').dataTable({
                 "bJQueryUI": true,
                 "sPaginationType": "full_numbers",
                 "bStateSave": true,
                 "iDisplayLength": 25
                 })
                 );
        ]]>
      </xsl:text>
    </script>
  </xsl:template>

  <!-- describes the columns for build set views -->
  <xsl:template name="genome_model_build_set_header" match="object[./types[./isa[@type='Genome::Model::Build']]]" mode="set_header">
    <xsl:comment>template: status/genome_model_build.xsl match: object[./types[./isa[@type='Genome::Model::Build']]] mode: set_header</xsl:comment>
    <tr>
      <th>
        build
      </th>
      <th>
        status
      </th>
      <th>
        model
      </th>
      <th>
        model id
      </th>
      <th>
        scheduled
      </th>
      <th>
        completed
      </th>
      <th>
        run by
      </th>

      <th>
        <br/>
      </th>

      <!-- <th> -->
      <!--   <br/> -->
      <!-- </th> -->
    </tr>
  </xsl:template>

  <!-- describes the row for build set views -->
  <xsl:template name="genome_model_build_set_row" match="object[./types[./isa[@type='Genome::Model::Build']]]" mode="set_row">
    <xsl:comment>template: status/genome_model.xsl match: object[./types[./isa[@type='Genome::Model::Build']]] mode: set_row</xsl:comment>
    <xsl:variable name="b_status" select="aspect[@name='status']/value"/>
    <xsl:variable name="lc_b_status" select="translate($b_status,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz')"/>

    <xsl:variable name="build_directory_url">
      <xsl:text>https://gscweb.gsc.wustl.edu/</xsl:text><xsl:value-of select="normalize-space(aspect[@name='data_directory']/value)" />
    </xsl:variable>

    <tr>
      <td>
        <xsl:call-template name="object_link_button">
          <xsl:with-param name="icon" select="'sm-icon-extlink'" />
          <xsl:with-param name="linktext">
            <xsl:value-of select="display_name" />
          </xsl:with-param>
        </xsl:call-template>
      </td>

      <td>
        <xsl:attribute name="class"><xsl:text>status </xsl:text><xsl:value-of select="$lc_b_status"/></xsl:attribute><xsl:value-of select="$lc_b_status"/>
      </td>

      <td>
        <xsl:for-each select="aspect[@name='model']/object">
          <xsl:value-of select="aspect[@name='name']/value" />
        </xsl:for-each>
      </td>

      <td>
        <xsl:for-each select="aspect[@name='model']/object">
          <xsl:call-template name="object_link_button">
            <xsl:with-param name="icon" select="'sm-icon-extlink'" />
            <xsl:with-param name="linktext">
              <xsl:value-of select="@id" />
            </xsl:with-param>
          </xsl:call-template>
        </xsl:for-each>
      </td>

      <td>
        <xsl:value-of select="aspect[@name='date_scheduled']"/>
      </td>

      <td>
        <xsl:choose>
          <xsl:when test="normalize-space(aspect[@name='date_completed'])">
            <xsl:value-of select="aspect[@name='date_completed']"/>
          </xsl:when>
          <xsl:otherwise>
            --
          </xsl:otherwise>
        </xsl:choose>
      </td>

      <td class="buttons">
        <xsl:value-of select="aspect[@name='run_by']/value"/>
      </td>

      <td class="buttons">
        <a class="mini btn"><xsl:attribute name="href"><xsl:value-of select='$build_directory_url'/></xsl:attribute><span class="sm-icon sm-icon-extlink"><br/></span>data directory</a>
      </td>

      <!-- <td class="buttons"> -->
      <!--   <xsl:call-template name="object_link_button_tiny"> -->
      <!--     <xsl:with-param name="icon" select="'sm-icon-extlink'" /> -->
      <!--   </xsl:call-template> -->
      <!-- </td> -->
    </tr>

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
