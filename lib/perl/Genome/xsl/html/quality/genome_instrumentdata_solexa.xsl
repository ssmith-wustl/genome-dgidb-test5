<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template name="genome_instrumentdata_solexa_quality" match="/report">
    <xsl:comment>file: html/quality/genome_instrumentdata_solexa.xsl name:genome_instrumentdata_solexa_quality</xsl:comment>
    <script type="text/javascript" src="/res/js/pkg/protovis.js"></script>
    <script type="text/javascript" src="/res/js/app/quality/genome_instrumentdata_solexa_bar.js"></script>
    <script type="text/javascript" src="/res/js/app/quality/genome_instrumentdata_solexa_candlestick.js"></script>


    <script type="text/javascript">
      <xsl:for-each select="//quality-stats/read-set">

        var <xsl:value-of select="@read-set-name"/>_data = [
        <xsl:for-each select="cycle">
          {
          column: <xsl:value-of select="column"/>,
          count: <xsl:value-of select="count"/>,
          quality_min: <xsl:value-of select="min"/>,
          quality_max: <xsl:value-of select="max"/>,
          quality_sum: <xsl:value-of select="sum"/>,
          quality_mean: <xsl:value-of select="mean"/>,
          quartile_q1: <xsl:value-of select="Q1"/>,
          quartile_med: <xsl:value-of select="med"/>,
          quartile_q3: <xsl:value-of select="Q3"/>,
          quartile_iqr: <xsl:value-of select="IQR"/>,
          whisker_left: <xsl:value-of select="lW"/>,
          whisker_right: <xsl:value-of select="rW"/>,
          count_a: <xsl:value-of select="A-Count"/>,
          count_c: <xsl:value-of select="C-Count"/>,
          count_g: <xsl:value-of select="G-Count"/>,
          count_t: <xsl:value-of select="T-Count"/>,
          count_n: <xsl:value-of select="N-Count"/>,
          read_set_name: "<xsl:value-of select="../@read-set-name"/>"
          },
        </xsl:for-each>
        ];
      </xsl:for-each>
    </script>

    <style type="text/css" media="screen">
      div.graph_placeholder {
      width: 100%;
      height: 480px;
      margin-bottom: 20px;
      margin-left: -2%;
      clear: both;
      }

      div.content_padding {
      padding: 0 10px 20px 10px;
      }

      div.graph_block {
      width: 48%;
      margin-left: 2%;
      float: left;
      }

      table.key {

      }

      table.key td.title{
      font-size: 83%;
      font-weight: bold;
      padding-right: 10px;
      }

      table.key td.graphic {
      width: 12px;
      height: 12px;
      }

      table.key td.value {
      font-size: 83%;
      padding-left: 3px;
      padding-right: 10px;
      }

    </style>

    <xsl:call-template name="control_bar_view"/>

    <xsl:call-template name="view_header">
      <xsl:with-param name="label_name" select="'Instrument Data Solexa:'" />
      <xsl:with-param name="display_name" select="@id" />
      <xsl:with-param name="icon" select="'genome_instrumentdata_32'" />
    </xsl:call-template>

    <div class="content rounded shadow">
      <div class="container">
        <div class="span-24 last">
          <table cellpadding="0" cellspacing="0" border="0" class="info_table_group">
            <tr>
              <td>
                <table border="0" cellpadding="0" cellspacing="0" class="info_table" width="100%">
                  <colgroup>
                    <col/>
                    <col width="100%"/>
                  </colgroup>
                  <tr><td class="label">ID:</td><td class="value"><xsl:value-of select="//instrument-data-info/id"/></td></tr>
                  <tr><td class="label">Sequencing Platform:</td><td class="value"><xsl:value-of select="//instrument-data-info/sequencing-platform"/></td></tr>
                  <tr><td class="label">Run Name:</td><td class="value"><xsl:value-of select="//instrument-data-info/run-name"/></td></tr>
                </table>
              </td>
              <td>
                <table border="0" cellpadding="0" cellspacing="0" class="info_table" width="100%">
                  <colgroup>
                    <col/>
                    <col width="100%"/>
                  </colgroup>
                  <tr><td class="label">Subset Name:</td><td class="value"><xsl:value-of select="//instrument-data-info/subset-name"/></td></tr>
                  <tr><td class="label">Sample Name:</td><td class="value"><xsl:value-of select="//instrument-data-info/sample-name"/></td></tr>
                  <tr><td class="label">Library Name:</td><td class="value"><xsl:value-of select="//instrument-data-info/library-name"/></td></tr>

                </table>
              </td>
            </tr>
          </table>

          <h2 class="report_section">Quality Stats and Nucleotide Distribution <span style="font-size: 75%; color: #666">(hover over columns for details)</span></h2>
          <xsl:for-each select="//quality-stats/read-set">
            <div class="graph_placeholder">
              <div class="graph_block">
                <h3><xsl:value-of select="@read-set-name"/> quality stats</h3>
                <table cellpadding="0" cellspacing="0" border="0" class="key">
                  <tr>
                    <td class="title">Legend:</td>

                    <td class="graphic" style="background-color: #d2d0a5;"></td>
                    <td class="value">whiskers</td>

                    <td class="graphic" style="background-color: #60604b;"></td>
                    <td class="value">high/low quartiles</td>

                    <td class="graphic" style="background-color: #f3b028;"></td>
                    <td class="value">med. quartile</td>
                  </tr>
                </table>
                <table width="100%" cellpadding="0" cellspacing="0" border="0">
                  <tr>
                    <td valign="middle">
                      <img src="/resources/report_resources/apipe_dashboard/images/axis_label_v_quality_sm.png" width="17" height="44" alt="Quality"/>
                    </td>
                    <td>
                      <script type="text/javascript">
                        render_candlestick_graph(<xsl:value-of select="@read-set-name"/>_data, 385, 400);
                      </script>
                    </td>
                  </tr>
                  <tr>
                    <td></td>
                    <td><div align="center"><img src="/resources/report_resources/apipe_dashboard/images/axis_label_h_col_count.png" width="93" height="16" alt="Cycle/Column"/></div></td>
                  </tr>
                </table>
              </div>

              <div class="graph_block">
                <h3><xsl:value-of select="@read-set-name"/> nucleotide distribution</h3>
                <table cellpadding="0" cellspacing="0" border="0" class="key">
                  <tr>
                    <td class="title">Legend:</td>

                    <td class="graphic" style="background-color: #7d598c;"></td>
                    <td class="value">A</td>

                    <td class="graphic" style="background-color: #bb4250;"></td>
                    <td class="value">C</td>

                    <td class="graphic" style="background-color: #90c86f;"></td>
                    <td class="value">G</td>

                    <td class="graphic" style="background-color: #f6c460;"></td>
                    <td class="value">T</td>

                    <td class="graphic" style="background-color: #999;"></td>
                    <td class="value">N</td>

                  </tr>
                </table>

                <table width="100%" cellpadding="0" cellspacing="0" border="0">
                  <tr>
                    <td>
                      <script type="text/javascript">
                        render_bar_graph(<xsl:value-of select="@read-set-name"/>_data, 385, 400);
                      </script>
                    </td>
                    <td valign="middle">
                      <img src="/resources/report_resources/apipe_dashboard/images/axis_label_v_read_count.png" width="13" height="71" alt="Read Count"/>
                    </td>
                  </tr>
                  <tr>
                    <td><div align="center"><img src="/resources/report_resources/apipe_dashboard/images/axis_label_h_col_count.png" width="93" height="16" alt="Cycle/Column"/></div></td>
                    <td></td>
                  </tr>
                </table>
              </div>
            </div>
          </xsl:for-each>
        </div>
      </div>
    </div>
  </xsl:template>
</xsl:stylesheet>
