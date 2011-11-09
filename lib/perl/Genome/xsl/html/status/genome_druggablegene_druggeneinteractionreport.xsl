<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template name="genome_druggablegene_druggeneinteractionreport" match="object[./types[./isa[@type='Genome::DruggableGene::DrugGeneInteractionReport']]]">

    <script type='text/javascript' src='/res/js/pkg/boxy/javascripts/jquery.boxy.js'></script>
    <link rel="stylesheet" href="/res/js/pkg/boxy/stylesheets/boxy.css" type="text/css" />
    <script type='text/javascript' src='/res/js/app/genome_model_build_list.js'></script>

    <xsl:call-template name="control_bar_view"/>

    <xsl:call-template name="view_header">
      <xsl:with-param name="label_name" select="'DrugGeneInteractionReport:'" />
      <xsl:with-param name="display_name" select="@id" />
      <xsl:with-param name="icon" select="'genome_druggeneinteractionreport_32'" />
    </xsl:call-template>

    <div class="content rounded shadow">
      <xsl:call-template name='DrugGeneInteractionReportDetail'/>

    </div> <!-- end content -->

    <xsl:call-template name="footer">
      <xsl:with-param name="footer_text">
        <br/>
      </xsl:with-param>
    </xsl:call-template>

  </xsl:template>

  <xsl:template name="name_value_table">
      <table border='1'>
          <tbody>
              <xsl:for-each select="aspect">
                  <tr>
                      <td><xsl:value-of select='string(@name)'/></td>
                      <td><xsl:value-of select='value/text()'/></td>
                  </tr>
              </xsl:for-each>
          </tbody>
      </table>
  </xsl:template>
  <xsl:template name='DrugGeneInteractionReportDetail'>
      <div class="container">
        <div id="objects" class="span-24 last">

          <!-- details for this DrugGeneInteractionReport -->
          <div class="span_8_box_masonry">
            <div class="box_header span-8 last rounded-top">
              <div class="box_title"><h3 class="nontyped span-7 last">Drug Gene Interaction Report Attributes</h3></div>
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
                    <td class="name">Interaction Type:
                    </td>
                    <td class="value">
                      <xsl:choose>
                        <xsl:when test="string(normalize-space(aspect[@name='interaction_type']/value))">
                          <xsl:value-of select="normalize-space(aspect[@name='interaction_type']/value)"/>
                        </xsl:when>
                        <xsl:otherwise>
                          --
                        </xsl:otherwise>
                      </xsl:choose>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div> <!-- end .masonry -->
        </div> <!-- end objects -->
      </div> <!-- end container -->
            <div class='container'>
          <div class="span-24 last">
              <h2><xsl:value-of select="aspect[@name='gene_name_report']/object/display_name/text()"/></h2>
              <xsl:for-each select="aspect[@name='gene_name_report']/object">
                <xsl:call-template name="name_value_table"/>
              </xsl:for-each>

              <h2><xsl:value-of select="aspect[@name='drug_name_report']/object/display_name/text()"/></h2>
              <xsl:for-each select="aspect[@name='drug_name_report']/object">
                <xsl:call-template name="name_value_table"/>
              </xsl:for-each>
          </div>
      </div> <!-- end container -->
  </xsl:template>
</xsl:stylesheet>
