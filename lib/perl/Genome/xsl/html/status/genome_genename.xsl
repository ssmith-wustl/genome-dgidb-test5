<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template name="genome_genename" match="object[./types[./isa[@type='Genome::GeneName']]]">
    <xsl:comment>template: /html/status/genome_GeneName.xsl; match="object[./types[./isa[@type='Genome::GeneName']]]"</xsl:comment>

    <script type='text/javascript' src='/res/js/pkg/boxy/javascripts/jquery.boxy.js'></script>
    <link rel="stylesheet" href="/res/js/pkg/boxy/stylesheets/boxy.css" type="text/css" />
    <script type='text/javascript' src='/res/js/app/genome_model_build_list.js'></script>

    <xsl:call-template name="control_bar_view"/>

    <xsl:call-template name="view_header">
      <xsl:with-param name="label_name" select="'GeneName:'" />
      <xsl:with-param name="display_name" select="@id" />
      <xsl:with-param name="icon" select="'genome_genename_32'" />
    </xsl:call-template>

    <div class="content rounded shadow">
      <div class="container">
        <div id="objects" class="span-24 last">

          <!-- details for this GeneName -->
          <div class="span_8_box_masonry">
            <div class="box_header span-8 last rounded-top">
              <div class="box_title"><h3 class="nontyped span-7 last">GeneName Attributes</h3></div>
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
                    <td class="name">Name:
                    </td>
                    <td class="value">
                      <xsl:choose>
                        <xsl:when test="string(normalize-space(aspect[@name='name']/value))">
                          <xsl:value-of select="normalize-space(aspect[@name='name']/value)"/>
                        </xsl:when>
                        <xsl:otherwise>
                          --
                        </xsl:otherwise>
                      </xsl:choose>
                    </td>
                  </tr>

                  <tr>
                    <td class="name">Nomenclature:
                    </td>
                    <td class="value">
                      <xsl:choose>
                        <xsl:when test="string(normalize-space(aspect[@name='nomenclature']/value))">
                          <xsl:value-of select="normalize-space(aspect[@name='nomenclature']/value)"/>
                        </xsl:when>
                        <xsl:otherwise>
                          --
                        </xsl:otherwise>
                      </xsl:choose>
                    </td>
                  </tr>

                  <tr>
                    <td class="name">Source Database Name:
                    </td>
                    <td class="value">
                      <xsl:choose>
                        <xsl:when test="string(normalize-space(aspect[@name='source_db_name']/value))">
                          <xsl:value-of select="normalize-space(aspect[@name='source_db_name']/value)"/>
                        </xsl:when>
                        <xsl:otherwise>
                          --
                        </xsl:otherwise>
                      </xsl:choose>
                    </td>
                  </tr>

                  <tr>
                    <td class="name">Source Database Version:
                    </td>
                    <td class="value">
                      <xsl:choose>
                        <xsl:when test="string(normalize-space(aspect[@name='source_db_version']/value))">
                          <xsl:value-of select="normalize-space(aspect[@name='source_db_version']/value)"/>
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
    </div> <!-- end content -->

    <xsl:call-template name="footer">
      <xsl:with-param name="footer_text">
        <br/>
      </xsl:with-param>
    </xsl:call-template>

  </xsl:template>
</xsl:stylesheet>
