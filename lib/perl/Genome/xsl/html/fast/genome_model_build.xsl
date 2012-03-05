<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <!-- full page display for a project -->
  <xsl:template name="genome_model_build" match="/object[./types[./isa[@type='Genome::Model::Build']]]">
    <xsl:comment>template: fast/genome_model_build.xsl match: object[./types[./isa[@type='Genome::Model::Build']]]</xsl:comment>
    <xsl:call-template name="control_bar_view"/>

    <xsl:call-template name="view_header">
      <xsl:with-param name="label_name" select="'Build'" />
      <xsl:with-param name="display_name" select="/object/display_name" />
      <xsl:with-param name="icon" select="'genome_model_build_32'" />
    </xsl:call-template>

    <script type="text/javascript" src="https://imp.gsc.wustl.edu/resources/report_resources/jquery/dataTables-1.5/media/js/jquery.dataTables.js"></script>
    <script type="text/javascript" src="https://imp.gsc.wustl.edu/resources/report_resources/jquery/dataTables-1.5/media/js/jquery.dataTables.plugin.formatted-num.js"></script>
    <link rel="stylesheet" href="https://imp.gsc.wustl.edu/resources/report_resources/jquery/dataTables-1.5/media/css/gc_table.css" type="text/css" media="screen"></link>

    <link rel="stylesheet" href="/res/css/genome_model_build.css" type="text/css" />
    <script type='text/javascript' src='/res/js/app/genome_model_build.js'></script>

    <div class="content rounded shadow">
      <div class="container">
        <div id="objects" class="span-24 last">

            <xsl:comment>left side attribute box</xsl:comment>
            <div class="span_8_box_masonry attrib-box">
                    <div class="box_header rounded-top span-8 last">
                        <div class="box_title"><h3 class="nontyped span-7 last">Attributes</h3></div>
                    </div>
                    <div class="box_content rounded-bottom span-8 last"><br/>
                        <dl>
                            <dt>status</dt>
                            <dd>
                                <xsl:value-of select="aspect[@name='master_event_status']/value"/><xsl:text>  </xsl:text>
                                <xsl:call-template name="notes_button"></xsl:call-template>
                            </dd>

                            <dt>run by</dt>
                            <dd><xsl:value-of select="aspect[@name='run_by']/value"/></dd>

                            <dt>model</dt>
                            <dd><xsl:value-of select="aspect[@name='model']/object/aspect[@name='name']"/>
                                &#160;<a>
                                <xsl:attribute name="href">
                                    <xsl:for-each select="/object/aspect[@name='model']/object">
                                        <xsl:call-template name="object_link_href"></xsl:call-template>
                                    </xsl:for-each> 
                                </xsl:attribute>
                                <xsl:value-of select="aspect[@name='model']/object/@id"/>
                                </a>
                            </dd>

                            <dt>subject</dt>
                            <dd><xsl:value-of select="aspect[@name='model']/object/aspect[@name='subject']/object/display_name"/>
                               &#160;<a>
                                <xsl:attribute name="href">
                                    <xsl:for-each select="aspect[@name='model']/object/aspect[@name='subject']/object/@id">
                                        <xsl:call-template name="object_link_href"></xsl:call-template>
                                    </xsl:for-each> 
                                </xsl:attribute>
                                <xsl:value-of select="aspect[@name='model']/object/aspect[@name='subject']/object/@id"/>
                                </a>
                            </dd>

                            <dt>files</dt>
                            <dd>
                                <a class="mini btn">
                                    <xsl:attribute name="href">
                                    <xsl:text>https://gscweb.gsc.wustl.edu/</xsl:text><xsl:value-of select="aspect[@name='data_directory']/value"/></xsl:attribute>
                                    <xsl:text>data dir</xsl:text>
                                </a>
                                <a class="mini btn"><xsl:attribute name="href"><xsl:text>https://gscweb.gsc.wustl.edu/</xsl:text><xsl:value-of select="build/@error-log"/></xsl:attribute>
                                    <xsl:text>error log</xsl:text>
                                </a>
                                <a class="mini btn"><xsl:attribute name="href"><xsl:text>https://gscweb.gsc.wustl.edu/</xsl:text><xsl:value-of select="build/@output-log"/></xsl:attribute>
                                    <xsl:text>output log</xsl:text>
                                </a>
                            </dd>
                        </dl>
                    </div>
            </div>

            <xsl:comment>right side attribute box</xsl:comment>
            <div class="span_8_box_masonry attrib-box">
                    <div class="box_header rounded-top span-8 last">
                        <div class="box_title"><h3 class="nontyped span-7 last"></h3></div>
                    </div>
                    <div class="box_content rounded-bottom span-8 last"> 
                        <dl>
                            <dt>software</dt>
                            <dd><xsl:value-of select="aspect[@name='software_revision']/value"/></dd>

                            <dt>processing profile</dt>
                            <dd><xsl:value-of select="aspect[@name='model']/object/aspect[@name='processing_profile']/object/aspect[@name='name']/value"/>
                               &#160;<a>
                                <xsl:attribute name="href">
                                    <xsl:for-each select="aspect[@name='model']/object/aspect[@name='processing_profile']/object">
                                        <xsl:call-template name="object_link_href"></xsl:call-template>
                                    </xsl:for-each> 
                                </xsl:attribute>
                                <xsl:value-of select="aspect[@name='model']/object/aspect[@name='processing_profile']/object/@id"/>
                                </a>
                            </dd>

                            <dt>workflow</dt>
                            <dd>
                                <xsl:for-each select="build/workflow">
                                    <xsl:call-template name="object_link_button">
                                     <xsl:with-param name="linktext">
                                     <xsl:value-of select="./@id"/>
                                    </xsl:with-param>
                                    <xsl:with-param name="icon" select="'sm-icon-extlink'" />
                                    </xsl:call-template>
                                </xsl:for-each>
                            </dd>

                            <dt>LSF job</dt>
                            <dd><xsl:value-of select="aspect[@name='the_master_event']/object/aspect[@name='lsf_job_id']/value"/></dd>
                        </dl>
                    </div>
            </div>

            <div style="clear:both">
            </div>

        </div> <!-- end .objects -->

            <xsl:comment>inputs box</xsl:comment>
            <xsl:if test="count(/object/aspect[@name='inputs']/object) > 0 ">
                <xsl:for-each select="/object/aspect[@name='inputs']">
                    <xsl:call-template name="genome_model_input_table"/>
                </xsl:for-each>
            </xsl:if>



      </div> <!-- end container -->
    </div> <!-- end content -->

    <xsl:call-template name="footer">
      <xsl:with-param name="footer_text">
        <br/>
      </xsl:with-param>
    </xsl:call-template>

  </xsl:template>


  <xsl:template name="notes_button">

        <xsl:variable name="note_count" select="count(/object/aspect[@name='notes']/object)"/>
        <xsl:variable name="build_id" select="build/@build-id"/>

        <xsl:choose>
          <xsl:when test="$note_count &gt; 0">
            <a class="notes-link mini btn notes-popup">
              <xsl:attribute name="title">Build <xsl:value-of select="$build_id"/> Notes</xsl:attribute>
              <xsl:attribute name="id"><xsl:value-of select="$build_id"/></xsl:attribute>
              <span class="sm-icon sm-icon-newwin"><br/></span>notes (<xsl:value-of select="$note_count"/>)
            </a>
            <!-- div for instrument data -->
            <div style="display: none;">
              <xsl:attribute name="id">notes_subject_<xsl:value-of select="$build_id"/></xsl:attribute>
              <table class="lister" border="0" width="100%" cellspacing="0" cellpadding="0">
                <colgroup>

                </colgroup>
                <thead>
                  <th>
                    header
                  </th>
                  <th>
                    date
                  </th>
                  <th>
                    editor id
                  </th>
                  <th>
                    <xsl:text> </xsl:text>
                  </th>

                </thead>
                <tbody>
                  <xsl:for-each select="build/aspect[@name='notes']/object">
                    <tr>
                      <td><strong><xsl:value-of select="aspect[@name='header_text']/value"/></strong></td>
                      <td><xsl:value-of select="aspect[@name='entry_date']/value"/></td>
                      <td><xsl:value-of select="aspect[@name='editor_id']/value"/></td>
                      <td class="buttons">
                        <xsl:for-each select="aspect[@name='subject']/object">
                          <xsl:call-template name="object_link_button">
                            <xsl:with-param name="linktext" select="'subject'"/>
                            <xsl:with-param name="icon" select="'sm-icon-extlink'"/>
                          </xsl:call-template>
                        </xsl:for-each>
                      </td>

                    </tr>
                    <tr>
                      <td colspan="4" class="text"><xsl:value-of select="aspect[@name='body_text']/value"/></td>
                    </tr>

                  </xsl:for-each>
                </tbody>
              </table>

            </div>
          </xsl:when>
        </xsl:choose>

  </xsl:template>

  <xsl:template name="genome_model_input_table">
    <xsl:comment>template: status/genome_model.xsl:genome_model_input_table</xsl:comment>
    <div class="generic_lister">
      <div class="box_header span-24 last rounded-top">
        <div class="box_title"><h3 class="genome_instrumentdata_16 span-24 last">Inputs</h3></div>
      </div>
      <div class="box_content rounded-bottom span-24 last">
        <table class="lister">
          <tbody>
            <xsl:for-each select="object[aspect[@name='name']/value!='instrument_data']">
              <xsl:sort select="aspect[@name='name']/value" data-type="text" order="ascending"/>
              <xsl:call-template name="genome_model_input_table_row"/>
            </xsl:for-each>

            <!-- It has been decided that instrument_data should be last -->
            <xsl:for-each select="object[aspect[@name='name']/value='instrument_data']">
              <xsl:sort select="aspect[@name='name']/value" data-type="text" order="ascending"/>
              <xsl:call-template name="genome_model_input_table_row"/>
            </xsl:for-each>

          </tbody>
        </table>
      </div> <!-- end box_content -->
    </div> <!-- end generic lister -->

  </xsl:template>

  <xsl:template name="genome_model_input_table_row">
    <xsl:comment>template: status/genome_model.xsl:genome_model_input_table_row</xsl:comment>
    <tr>

      <td><xsl:value-of select="normalize-space(aspect[@name='name']/value)"/></td>

      <td style="width: 100%">
        <xsl:call-template name="genome_model_input_value_link"/>
      </td>

    </tr>
  </xsl:template>

  <xsl:template name="genome_model_input_value_link">
    <xsl:call-template name="object_link_button">
      <xsl:with-param name="icon" select="'sm-icon-extlink'" />
      <xsl:with-param name="id">
        <xsl:value-of select="aspect[@name='value_id']/value"/>
      </xsl:with-param>

      <xsl:with-param name="type">
        <xsl:value-of select="aspect[@name='value_class_name']/value"/>
      </xsl:with-param>

      <xsl:with-param name="linktext">
        <xsl:choose>
          <xsl:when test="aspect[@name='value']/object/display_name">
            <xsl:value-of select="aspect[@name='value']/object/display_name"/>
          </xsl:when>
          <xsl:when test="display_name">
            <xsl:value-of select="display_name"/>
          </xsl:when>
          <xsl:otherwise>
            could not resolve display_name
          </xsl:otherwise>
        </xsl:choose>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>


</xsl:stylesheet>
