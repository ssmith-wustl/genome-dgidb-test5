<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <!-- full page template for models -->
  <xsl:template name="genome_model" match="object[./types[./isa[@type='Genome::Model']]]">
    <!-- These parameters are only valid when there is a last_complete_build; they are here for overriding by subclasses -->
    <xsl:param name="build_directory_url">
      <xsl:text>https://gscweb.gsc.wustl.edu/</xsl:text><xsl:value-of select="normalize-space(aspect[@name='last_complete_build']/object/aspect[@name='data_directory']/value)" />
    </xsl:param>
    <xsl:param name="summary_report_url">
      <xsl:value-of select="$build_directory_url"/><xsl:text>/reports/Summary/report.html</xsl:text>
    </xsl:param>

    <xsl:comment>template: status/genome_model.xsl match: object[./types[./isa[@type='Genome::Model']]]</xsl:comment>

    <xsl:call-template name="view_header">
      <xsl:with-param name="label_name" select="'Model'" />
      <xsl:with-param name="display_name" select="./aspect[@name='name']/value" />
      <xsl:with-param name="icon" select="'genome_model_32'" />
    </xsl:call-template>

    <div class="content rounded shadow">
      <div class="container">
        <div id="objects" class="span-24 last">

          <xsl:call-template name="genome_model_attributes_box"/>

          <xsl:for-each select="aspect[@name='processing_profile']/object">
            <xsl:call-template name="genome_processingprofile_box"/>
          </xsl:for-each>

        </div> <!-- end .objects -->

        <xsl:if test="count(aspect[@name='inputs']) > 0 ">
          <xsl:for-each select="aspect[@name='inputs']">
            <xsl:call-template name="genome_model_input_table"/>
          </xsl:for-each>
        </xsl:if>

        <xsl:if test="count(aspect[@name='to_models'] | aspect[@name='from_models']) > 0">
          <xsl:call-template name="genome_model_link_table"/>
        </xsl:if>

        <xsl:call-template name="genome_model_build_lister"/>

      </div> <!-- end container -->
    </div> <!-- end content -->

    <xsl:call-template name="footer">
      <xsl:with-param name="footer_text">
        <br/>
      </xsl:with-param>
    </xsl:call-template>

  </xsl:template>

  <xsl:template name="genome_model_build_lister">
    <div class="generic_lister">
      <div class="box_header span-24 last rounded-top">
        <div class="box_title"><h3 class="genome_model_build_16 span-24 last">Builds</h3></div>
      </div>
      <div class="box_content rounded-bottom span-24 last">
        <table class="lister">
          <thead>
            <tr>
              <th>build</th>
              <th>status</th>
              <th>scheduled</th>
              <th>completed</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <xsl:for-each select="aspect[@name='builds']/object">
                <xsl:call-template name="genome_model_builds_list_table_row" />
              </xsl:for-each>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </xsl:template>

  <xsl:template name="genome_model_attributes_box">
    <xsl:param name="build_directory_url">
      <xsl:text>https://gscweb.gsc.wustl.edu/</xsl:text><xsl:value-of select="normalize-space(aspect[@name='last_complete_build']/object/aspect[@name='data_directory']/value)" />
    </xsl:param>

    <xsl:param name="summary_report_url">
      <xsl:value-of select="$build_directory_url"/><xsl:text>/reports/Summary/report.html</xsl:text>
    </xsl:param>

    <xsl:comment>template: genome_model.xsl:genome_model_attributes_box</xsl:comment>
    <!-- details for this model -->
    <div class="span_8_box_masonry">
      <div class="box_header span-8 last rounded-top">
        <div class="box_title"><h3 class="nontyped span-7 last">Model Attributes</h3></div>
        <div class="box_button">

        </div>
      </div>

      <div class="box_content rounded-bottom span-8 last">
        <table class="name-value">
          <tbody>
            <tr>
              <td class="name">ID:
              </td>
              <td class="value"><xsl:value-of select="@id"/>
              </td>
            </tr>

            <tr>
              <td class="name">Creation Date:
              </td>
              <td class="value"><xsl:value-of select="aspect[@name='creation_date']/value"/>
              </td>
            </tr>

            <tr>
              <td class="name">Created by:
              </td>
              <td class="value"><xsl:value-of select="aspect[@name='user_name']/value"/>
              </td>
            </tr>

            <xsl:choose>
              <xsl:when test="aspect[@name='last_complete_build']/object">

                <tr>
                  <td class="name">Last Complete Build:
                  </td>
                  <td class="value">
                    <xsl:for-each select="aspect[@name='last_complete_build']/object">
                      <xsl:call-template name="object_link_button">

                        <xsl:with-param name="linktext" select="@id" />
                        <xsl:with-param name="icon" select="'sm-icon-extlink'" />
                      </xsl:call-template>
                    </xsl:for-each>
                  </td>
                </tr>

                <tr>
                  <td class="name"><br/>
                  </td>
                  <td class="value">

                    <a class="mini btn"><xsl:attribute name="href"><xsl:value-of select='$build_directory_url'/></xsl:attribute><span class="sm-icon sm-icon-extlink"><br/></span>data directory</a>

                  </td>
                </tr>

                <tr>
                  <td class="name"><br/>
                  </td>
                  <td class="value">

                    <a class="mini btn"><xsl:attribute name="href"><xsl:value-of select='$summary_report_url'/></xsl:attribute><span class="sm-icon sm-icon-extlink"><br/></span>summary report</a>

                  </td>
                </tr>

              </xsl:when>
              <xsl:otherwise>
                <tr>
                  <td class="name">Last Complete Build:
                  </td>
                  <td class="value">
                    --
                  </td>
                </tr>
              </xsl:otherwise>
            </xsl:choose>

            <tr>
              <td class="name">Subject Type:
              </td>
              <td class="value"><xsl:value-of select="normalize-space(aspect[@name='subject_class_name']/value)"/>
              </td>
            </tr>

            <tr>
              <td class="name">Subject:
              </td>
              <td class="value">
                <xsl:choose>
                  <xsl:when test="substring(normalize-space(aspect[@name='subject_class_name']/value),1,3) != 'GSC'">
                    <xsl:call-template name="object_link_button">
                      <xsl:with-param name="icon" select="'sm-icon-extlink'" />
                      <xsl:with-param name="type" select="normalize-space(aspect[@name='subject_class_name']/value)"/>
                      <xsl:with-param name="id" select="normalize-space(aspect[@name='subject_id']/value)"/>
                      <xsl:with-param name="linktext">
                        <xsl:value-of select="normalize-space(aspect[@name='subject_id']/value)"/>
                      </xsl:with-param>
                    </xsl:call-template>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:value-of select="normalize-space(aspect[@name='subject_id']/value)"/>
                  </xsl:otherwise>
                </xsl:choose>
              </td>
            </tr>

          </tbody>
        </table>
      </div>
    </div>

  </xsl:template>


  <xsl:template name="genome_model_input_table">
    <xsl:comment>template: status/genome_model.xsl:genome_model_input_table</xsl:comment>
    <div class="generic_lister">
      <div class="box_header span-24 last rounded-top">
        <div class="box_title"><h3 class="genome_instrumentdata_16 span-24 last">Inputs</h3></div>
      </div>
      <div class="box_content rounded-bottom span-24 last">
        <table class="lister">
          <thead>
            <tr>
              <th>type</th>
              <th>object</th>
              <th><br/></th>
            </tr>
          </thead>
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
      <td><xsl:value-of select="display_name"/></td>
      <td class="buttons">
        <xsl:call-template name="object_link_button_tiny">
          <xsl:with-param name="icon" select="'sm-icon-extlink'" />
          <xsl:with-param name="id">
            <xsl:value-of select="aspect[@name='value_id']/value"/>
          </xsl:with-param>
          <xsl:with-param name="type">
            <xsl:value-of select="aspect[@name='value_class_name']/value"/>
          </xsl:with-param>
        </xsl:call-template>
      </td>
    </tr>
  </xsl:template>

  <xsl:template name="genome_model_link_table">
    <xsl:comment>template: status/genome_model.xsl:genome_ model_link_table</xsl:comment>
    <div class="generic_lister">
      <div class="box_header span-24 last rounded-top">
        <div class="box_title"><h3 class="genome_model_16 span-24 last">Model Links</h3></div>
      </div>
      <div class="box_content rounded-bottom span-24 last">
        <table class="lister">
          <thead>
            <tr>
              <th>direction</th>
              <th>model</th>
              <th><br/></th>
            </tr>
          </thead>
          <tbody>
            <xsl:for-each select="aspect[@name='to_models']/object | aspect[@name='to_builds']/object">
              <xsl:call-template name="genome_model_link_table_row">
                <xsl:with-param name="type">to</xsl:with-param>
              </xsl:call-template>
            </xsl:for-each>
            <xsl:for-each select="aspect[@name='from_models']/object | aspect[@name='from_builds']/object">
              <xsl:call-template name="genome_model_link_table_row">
                <xsl:with-param name="type">from</xsl:with-param>
              </xsl:call-template>
            </xsl:for-each>
          </tbody>
        </table>
      </div>
    </div>

  </xsl:template>

  <xsl:template name="genome_model_link_table_row">
    <xsl:param name="type" select="''" />

    <xsl:comment>template: status/genome_model.xsl:genome_model_link_table_table_row</xsl:comment>

    <tr>
      <td><xsl:value-of select="$type"/></td>
      <td>
        <xsl:value-of select="@type"/><xsl:text>: </xsl:text>
        <xsl:choose>
          <xsl:when test="aspect[@name='name']/value">
            <xsl:value-of select="aspect[@name='name']/value"/> (#<xsl:value-of select="@id"/>)
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="@id"/>
          </xsl:otherwise>
        </xsl:choose>
      </td>
      <td class="buttons">
        <xsl:call-template name="object_link_button_tiny">
          <xsl:with-param name="icon" select="'sm-icon-extlink'" />
        </xsl:call-template>
      </td>
    </tr>
  </xsl:template>

  <!-- genome model w/ build list template -->

  <xsl:template name="genome_model_builds_list_table">
    <xsl:variable name="is_default" select="aspect[@name='is_default']/value" />

    <xsl:comment>template: status/genome_model.xsl:genome_model_builds_list_table</xsl:comment>
    <div class="model_builds_list">
      <div class="box_header span-24 last rounded-top">
        <div class="box_title">
          <table cellpadding="0" cellspacing="0" border="0" class="name-value-row">
            <tr>
              <td class="model_name" colspan="6">
                <h3>
                  <xsl:attribute name="class">
                    <xsl:choose>
                      <xsl:when test="$is_default = 1">genome_model_default_16</xsl:when>
                      <xsl:otherwise>genome_model_16</xsl:otherwise>
                    </xsl:choose>
                  </xsl:attribute>

                  <xsl:value-of select="aspect[@name='name']/value"/>

                </h3>
              </td>
            </tr>
          </table>
        </div>
        <div class="box_button">
          <xsl:call-template name="object_link_button_tiny">
            <xsl:with-param name="icon" select="'sm-icon-extlink'"/>
          </xsl:call-template>
        </div>
      </div> <!-- end box header -->
      <xsl:variable name="num_builds" select="count(aspect[@name='builds']/object)"/>

      <div class="box_header_details rounded-bottom">
        <table class="name-value-row" cellpadding="0" cellspacing="0" border="0" style="margin-left: 27px;">
          <tr>
            <tr>
              <td class="name">
                model id:
              </td>
              <td class="value">
                <xsl:value-of select="@id"/>
              </td>
              <td class="name">
                username:
              </td>
              <td class="value">
                <xsl:value-of select="aspect[@name='user_name']/value"/>
              </td>
              <td class="name">
                scheduled:
              </td>
              <td class="value">
                <xsl:value-of select="aspect[@name='creation_date']/value"/>
              </td>

              <td class="name">
                builds:
              </td>
              <td class="value">
                <xsl:value-of select="$num_builds"/>
              </td>

            </tr>
          </tr>
        </table>
      </div>
      <div class="span-23 prepend-1 last">
        <div class="box_content rounded span-23 last" style="margin-bottom: 20px; margin-top: 5px;">

          <xsl:if test="$num_builds &gt; 0">
            <table cellpadding="0" cellspacing="0" border="0" class="lister">
              <thead>
                <tr>
                  <th class="rounded-left">build</th>
                  <th class="center">status</th>
                  <th class="right">scheduled</th>
                  <th class="right">completed</th>
                  <th class="rounded-right"><br/></th>
                </tr>
              </thead>
              <tbody>
                <xsl:choose>
                  <xsl:when test="count(aspect[@name='builds']/object) > 0">
                    <xsl:for-each select="aspect[@name='builds']/object">
                      <xsl:call-template name="genome_model_builds_list_table_row" />
                    </xsl:for-each>
                  </xsl:when>
                  <xsl:when test="count(aspect[@name='last_succeeded_build']/object) > 0" >
                    <xsl:for-each select="aspect[@name='last_succeeded_build']/object">
                      <xsl:call-template name="genome_model_builds_list_table_row" />
                    </xsl:for-each>
                  </xsl:when>
                  <xsl:when test="count(aspect[@name='last_complete_build']/object) > 0" >
                    <xsl:for-each select="aspect[@name='last_complete_build']/object">
                      <xsl:call-template name="genome_model_builds_list_table_row" />
                    </xsl:for-each>
                  </xsl:when>
                  <xsl:otherwise>
                    <tr>
                      <td></td>
                      <td colspan="6">
                        <strong>No builds found for this model.</strong>
                      </td>
                    </tr>
                  </xsl:otherwise>
                </xsl:choose>

              </tbody>
            </table>
          </xsl:if>
        </div> <!-- end box_content -->
      </div>
    </div><!-- end model_builds_list -->

  </xsl:template>


  <xsl:template name="genome_model_builds_list_table_row">
    <xsl:variable name="b_status" select="aspect[@name='status']/value"/>
    <xsl:variable name="lc_b_status" select="translate($b_status,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz')"/>
    <tr>
      <td>
        <xsl:value-of select="@id"/>
      </td>
      <td>
        <xsl:attribute name="class"><xsl:text>status </xsl:text><xsl:value-of select="$lc_b_status"/></xsl:attribute><xsl:value-of select="$lc_b_status"/>
      </td>
      <td class="right">
        <xsl:value-of select="aspect[@name='date_scheduled']/value"/>
      </td>
      <td class="right">
        <xsl:value-of select="aspect[@name='date_completed']/value"/>
      </td>
      <td class="buttons">
        <xsl:call-template name="object_link_button_tiny">
          <xsl:with-param name="icon" select="'sm-icon-extlink'"/>
        </xsl:call-template>
      </td>
    </tr>

  </xsl:template>

  <!-- DEPRECATED TEMPLATES -->
  <!-- MODEL w/ BUILDS LIST TEMPLATES  -->

  <xsl:template name="genome_model_build_table">
    <xsl:param name="want_builds" select="1" />

    <xsl:comment>template: status/genome_model.xsl:genome_model_build_table</xsl:comment>

    <!-- Called on a node containing one or more object nodes of type model -->
    <table id="model_list" class="list" width="100%" cellspacing="0" cellpadding="0" border="0" style="clear:both">
      <colgroup>
        <col width="40%" />
        <col />
        <col />
        <col />
      </colgroup>
      <tbody>
        <xsl:for-each select="object[./types[./isa[@type='Genome::Model']]]">
          <xsl:sort select="aspect[@name='name']/value" data-type="text" order="ascending"/>
          <xsl:variable name="is_default" select="aspect[@name='is_default']/value" />
          <tr class="model_row_header">
            <td class="model_name">
              <xsl:if test="$is_default = 1">
                <!-- if this is the default model, show a nice little star -->
                <img class="default_report_star" src="/res/old/report_resources/apipe_dashboard/images/icons/star_16.png" width="16" height="16" absmiddle="middle" alt="Default Model"/>
              </xsl:if>
              <xsl:call-template name="object_link"/>
            </td>
            <td>
              <strong>model id: </strong><xsl:value-of select="@id"/>
            </td>
            <td><strong>username: </strong><xsl:value-of select="aspect[@name='user_name']/value"/></td>
            <td class="last"><strong>scheduled: </strong><xsl:value-of select="aspect[@name='creation_date']/value"/></td>
          </tr>
          <xsl:if test="$want_builds = 1">
            <tr>
              <td colspan="4" class="subtable_cell">
                <xsl:call-template name="genome_model_build_table_section"/>
              </td>
            </tr>
          </xsl:if>
        </xsl:for-each>
      </tbody>
    </table>
  </xsl:template>

  <xsl:template name="genome_model_build_table_section">
    <xsl:comment>template: status/genome_model.xsl:genome_ model_build_table_section</xsl:comment>
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="subtable">
      <colgroup>
        <col width="25%" />
        <col width="15%"/>
        <col width="15%"/>
        <col width="15%"/>
        <col width="15%"/>
        <col width="15%"/>
      </colgroup>
      <thead>
        <th class="subtable_label">BUILDS</th>
        <th>build id</th>
        <th>status</th>
        <th>date scheduled</th>
        <th>date completed</th>
      </thead>
      <tbody>
        <xsl:choose>
          <xsl:when test="count(aspect[@name='builds']/object) > 0">
            <xsl:for-each select="aspect[@name='builds']/object">
              <xsl:call-template name="genome_model_build_table_row" />
            </xsl:for-each>
          </xsl:when>
          <xsl:when test="count(aspect[@name='last_succeeded_build']/object) > 0" >
            <xsl:for-each select="aspect[@name='last_succeeded_build']/object">
              <xsl:call-template name="genome_model_build_table_row" />
            </xsl:for-each>
          </xsl:when>
          <xsl:when test="count(aspect[@name='last_complete_build']/object) > 0" >
            <xsl:for-each select="aspect[@name='last_complete_build']/object">
              <xsl:call-template name="genome_model_build_table_row" />
            </xsl:for-each>
          </xsl:when>
          <xsl:otherwise>
            <tr>
              <td></td>
              <td colspan="5">
                <strong>No builds found for this model.</strong>
              </td>
            </tr>
          </xsl:otherwise>
        </xsl:choose>
      </tbody>
    </table>
  </xsl:template>

  <xsl:template name="genome_model_build_table_row">
    <xsl:comment>template: status/genome_model.xsl:genome_ model_build_table_row</xsl:comment>
    <tr onmouseover="this.className = 'hover'" onmouseout="this.className=''">
      <xsl:attribute name="onclick">
        <xsl:text>javascript:document.location.href='</xsl:text>
        <xsl:call-template name="object_link_href" />
        <xsl:text>'</xsl:text>
      </xsl:attribute>
      <td>

      </td>
      <td>
        <xsl:call-template name="object_link">
          <xsl:with-param name="linktext"><xsl:value-of select="@id"/></xsl:with-param>
        </xsl:call-template>
      </td>
      <td><xsl:attribute name="class"><xsl:text>status </xsl:text><xsl:value-of select="aspect[@name='status']/value"/></xsl:attribute>
      <xsl:value-of select="aspect[@name='status']/value"/>
      </td>
      <td>
        <xsl:value-of select="aspect[@name='date_scheduled']/value"/>
      </td>
      <td>
        <xsl:value-of select="aspect[@name='date_completed']/value"/>
      </td>
    </tr>
  </xsl:template>


</xsl:stylesheet>
