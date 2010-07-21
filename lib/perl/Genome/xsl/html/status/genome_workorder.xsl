<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template name="genome_workorder" match="object[./types[./isa[@type='Genome::WorkOrder']]]">

    <xsl:variable name="lowercase" select="'abcdefghijklmnopqrstuvwxyz'" />
    <xsl:variable name="uppercase" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ'" />
    <style type="text/css">
      table.item_header {
      background: #EFEFEF;
      margin: 0;
      padding: 0;
      }

      table.item_header td {
      vertical-align: middle;
      padding: 5px;
      border-bottom: 1px solid #CCC;
      border-top: 1px solid #CCC;
      }

      table.item_header td.item_title {
      font-weight: bold;
      font-size: 16px;
      line-height: 22px;
      width: 100%;
      }

      table.item_header td.item_attr_label {
      font-weight: bold;
      text-align: right;
      white-space: nowrap;
      }

      table.item_header td.item_attr_value {
      white-space: nowrap;
      padding-right: 15px;
      }

      table.wo_item td.stages_cell {
      vertical-align: top;
      }

      table.stages td.stage_cell {
      padding: 0;
      margin: 0;
      border-right: 2px solid #FFF;
      }

      table.stages {
      margin: 0;
      padding: 0;
      }

      table.stages td.wo_item_category {
      font-weight: bold;
      border-bottom: 1px solid #CCC;
      padding: 3px;
      line-height: 14px;
      }

      table.stage_table {
      margin: 0;
      padding: 0;
      width: 100%;
      }

      table.stage_table th {
      border-bottom: none;
      font-size: 9px;
      }

      table.stages td.notice {
      padding-top: 5px;
      color: #666;
      }

      td.stage_name {
      font-weight: bold;
      padding: 3px;
      background: #EFEFEF;
      }

    </style>


    <h2 class="page_title"><xsl:value-of select="//label_name"/> (<xsl:value-of select="//display_name"/>)</h2>
    <table cellpadding="0" cellspacing="0" border="0" class="info_table_group">
      <tr>
        <td>
          <table border="0" cellpadding="0" cellspacing="0" class="info_table" width="100%">
            <tr>
              <td class="label">Pipeline:</td>
              <td class="value"><xsl:value-of select="//aspect[@name='pipeline']/value"/></td>
              <td class="label">Project:</td>
              <td class="value"><xsl:value-of select="//aspect[@name='project']/object[@type='Genome::Project']/aspect[@name='name']"/></td>
              <td class="label">Project ID:</td>
              <td class="value"><xsl:value-of select="//aspect[@name='project']/object[@type='Genome::Project']/display_name"/></td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
    <hr/>

    <div class="page_padding">
      <xsl:for-each select="//aspect[@name='items']/object[@type='Genome::WorkOrderItem']">

        <!-- set up some variable to calculate stage cell widths -->
        <xsl:variable name="production_stages" select="count(aspect[@name='event_statuses']/perldata/hashref/item[@key='production']/hashref/item)"/>
        <xsl:variable name="analysis_stages" select="count(aspect[@name='event_statuses']/perldata/hashref/item[@key='analysis']/hashref/item)"/>
        <xsl:variable name="total_stages" select="$production_stages + $analysis_stages"/>
        <xsl:variable name="prod_width" select="floor((100 div $total_stages) * $production_stages)"/>
        <xsl:variable name="prod_stage_width" select="floor(100 div $production_stages)"/>
        <xsl:variable name="analysis_stage_width" select="floor(100 div $analysis_stages)"/>
        <xsl:variable name="analysis_width" select="floor((100 div $total_stages) * $analysis_stages)"/>
        <xsl:variable name="stage_width" select="floor(100 div $total_stages)"/>

        <table width="100%" class="wo_item">
          <tr>
            <td colspan="2">
              <table width="100%" class="item_header">
                <tr>
                  <td class="item_title"><xsl:value-of select="label_name"/> (<xsl:value-of select="display_name"/>)</td>
                  <td class="item_attr_label">Sample:</td>
                  <td class="item_attr_value"><a><xsl:attribute name="href">/view/Genome/Sample/status.html?id=<xsl:value-of select="aspect[@name='sample']/object/display_name"/></xsl:attribute> <xsl:value-of select="aspect[@name='sample']/object/aspect[@name='name']/value"/></a></td>
                  <td class="item_attr_label">Species Name:</td>
                  <td class="item_attr_value"><xsl:value-of select="aspect[@name='sample']/object/aspect[@name='species_name']/value"/></td>
                  <td class="item_attr_label">Common Name:</td>
                  <td class="item_attr_value"><xsl:value-of select="aspect[@name='sample']/object/aspect[@name='common_name']/value"/></td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td class="stages_cell" style="border-right: 2px solid #FFF;" width="{$prod_width}%">
              <table width="100%" class="stages" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td class="wo_item_category" colspan="4">Production</td>
                </tr>
                <tr>
                  <xsl:choose>
                    <xsl:when test="count(aspect[@name='event_statuses']/perldata/hashref/item[@key='production']/hashref/item) > 0">
                      <xsl:for-each select="aspect[@name='event_statuses']/perldata/hashref/item[@key='production']/hashref/item">
                        <xsl:sort order="ascending" data-type="number" select="hashref/item/hashref/item[@key='sort_order']"/>
                        <td class="stage_cell" width="{$prod_stage_width}%">
                          <table class="stage_table" cellpadding="0" cellspacing="0" border="0">
                            <colgroup>
                              <col width="33%"/>
                              <col width="33%"/>
                              <col width="34%"/>
                            </colgroup>
                            <tr>
                              <td colspan="3" class="stage_name">
                                <xsl:value-of select="@key"/>
                              </td>
                            </tr>
                            <tr>
                              <th>In Progress</th>
                              <th>Succeeded</th>
                              <th>Failed</th>
                            </tr>
                            <tr class="status_row">
                              <td class="scheduled">
                                <xsl:choose>
                                  <xsl:when test="hashref/item[@key='scheduled']/hashref/item[@key='count']">
                                    <xsl:value-of select="hashref/item[@key='scheduled']/hashref/item[@key='count']"/>
                                  </xsl:when>
                                  <xsl:otherwise>
                                    0
                                  </xsl:otherwise>
                                </xsl:choose>
                              </td>
                              <td class="succeeded">
                                <xsl:choose>
                                  <xsl:when test="hashref/item[@key='completed']/hashref/item[@key='count']">
                                    <xsl:value-of select="hashref/item[@key='completed']/hashref/item[@key='count']"/>
                                  </xsl:when>
                                  <xsl:otherwise>
                                    0
                                  </xsl:otherwise>
                                </xsl:choose>
                              </td>
                              <td class="failed">
                                <xsl:choose>
                                  <xsl:when test="hashref/item[@key='failed']/hashref/item[@key='count']">
                                    <xsl:value-of select="hashref/item[@key='failed']/hashref/item[@key='count']"/>
                                  </xsl:when>
                                  <xsl:otherwise>
                                    0
                                  </xsl:otherwise>
                                </xsl:choose>
                              </td>
                            </tr>
                          </table>
                        </td>
                      </xsl:for-each>
                    </xsl:when>
                    <xsl:otherwise>
                      <td class="notice"><p>No Production events found for this Work Order Item.</p></td>
                    </xsl:otherwise>
                  </xsl:choose>
                </tr>
              </table>
            </td>
            <td class="stages_cell" width="{$analysis_width}%">
              <table width="100%" class="stages">
                <tr>
                  <td class="wo_item_category">Analysis</td>
                </tr>
                <tr>
                  <xsl:for-each select="aspect[@name='event_statuses']/perldata/hashref/item[@key='analysis']/hashref/item">
                    <xsl:sort select="hashref/item/hashref/item/hashref/item[@key='sort_order']"/>
                    <td class="stage_cell" width="{$analysis_stage_width}%">
                      <table class="stage_table" cellpadding="0" cellspacing="0" border="0">
                        <colgroup>
                          <col width="33%"/>
                          <col width="33%"/>
                          <col width="34%"/>
                        </colgroup>
                        <tr>
                          <td colspan="3" class="stage_name">
                            <xsl:value-of select="@key"/>
                          </td>
                        </tr>
                        <tr>
                          <th>In Progress</th>
                          <th>Succeeded</th>
                          <th>Failed</th>
                        </tr>
                        <tr class="status_row">
                          <td class="scheduled">
                            <xsl:choose>
                              <xsl:when test="hashref/item[@key='scheduled']/hashref/item[@key='count']">
                                <xsl:value-of select="hashref/item[@key='scheduled']/hashref/item[@key='count']"/>
                              </xsl:when>
                              <xsl:otherwise>
                                0
                              </xsl:otherwise>
                            </xsl:choose>
                          </td>
                          <td class="succeeded">
                            <xsl:choose>
                              <xsl:when test="hashref/item[@key='completed']/hashref/item[@key='count']">
                                <xsl:value-of select="hashref/item[@key='completed']/hashref/item[@key='count']"/>
                              </xsl:when>
                              <xsl:otherwise>
                                0
                              </xsl:otherwise>
                            </xsl:choose>
                          </td>
                          <td class="failed">
                            <xsl:choose>
                              <xsl:when test="hashref/item[@key='failed']/hashref/item[@key='count']">
                                <xsl:value-of select="hashref/item[@key='failed']/hashref/item[@key='count']"/>
                              </xsl:when>
                              <xsl:otherwise>
                                0
                              </xsl:otherwise>
                            </xsl:choose>
                          </td>
                        </tr>
                      </table>
                    </td>
                  </xsl:for-each>
                </tr>
              </table>
            </td>
          </tr>
        </table>

        <table width="100%" cellpadding="0" cellspacing="0" border="0" class="list tablesorter" id="build_list">
          <colgroup>
            <col />
            <col />
            <col />
            <col />
            <col />
            <col />
          </colgroup>
          <thead>
            <th>model</th>
            <th>latest build</th>
            <th>build status</th>
          </thead>
          <tbody>
            <xsl:choose>
              <xsl:when test="count(aspect[@name='models']/object) > 0">
                <xsl:for-each select="aspect[@name='models']/object">
                  <tr>
                    <td>
                      <a><xsl:attribute name="href">/view/Genome/Model/status.html?id=<xsl:value-of select="display_name"/></xsl:attribute><xsl:value-of select="display_name"/></a> (<xsl:value-of select="aspect[@name='name']/value"/>)
                    </td>
                    <td>
                      <a><xsl:attribute name="href">/view/Genome/Model/Build/status.html?id=<xsl:value-of select="aspect[@name='latest_build']/object/display_name"/></xsl:attribute><xsl:value-of select="aspect[@name='latest_build']/object/display_name"/></a>
                    </td>
                    <td><xsl:attribute name="class"><xsl:text>status </xsl:text><xsl:value-of select="translate(aspect[@name='latest_build']/object/aspect[@name='master_event_status']/value, $uppercase, $lowercase)"/></xsl:attribute>
                    <xsl:value-of select="aspect[@name='latest_build']/object/aspect[@name='master_event_status']/value"/>
                    </td>
                  </tr>
                </xsl:for-each>
              </xsl:when>
              <xsl:otherwise>
                <tr>
                  <td colspan="3">
                    <strong>No models found for this Work Order Item.</strong>
                  </td>
                </tr>
              </xsl:otherwise>
            </xsl:choose>
          </tbody>
        </table>
        <br/>
      </xsl:for-each>
    </div>
  </xsl:template>

</xsl:stylesheet>
