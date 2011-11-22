<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template name="genome_druggablegene_drugnamereport_set" match="object[./types[./isa[@type='Genome::DruggableGene::DrugNameReport::Set']]]">

    <script type='text/javascript' src='/res/js/pkg/boxy/javascripts/jquery.boxy.js'></script>
    <link rel="stylesheet" href="/res/js/pkg/boxy/stylesheets/boxy.css" type="text/css" />
    <script type='text/javascript' src='/res/js/app/genome_model_build_list.js'></script>

    <xsl:call-template name="control_bar_view"/>

    <xsl:variable name='header_name'>
        <xsl:choose>
            <xsl:when test='count(aspect[@name="name"]/value)=1'>
                <xsl:value-of select='aspect[@name="name"]/value'/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select='./display_name'/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <xsl:call-template name="view_header">
      <xsl:with-param name="label_name" select="'DrugName:'" />
      <xsl:with-param name="display_name" select='$header_name'/>
      <xsl:with-param name="icon" select="'genome_drugname_32'" />
    </xsl:call-template>

    <div class="content rounded shadow">
      <div class="container">
          <xsl:for-each select="aspect[@name='members']/object">
              <xsl:call-template name="genome_drugnamereport_box"/>
          </xsl:for-each>
      </div> <!-- end container -->
    </div> <!-- end content -->

    <xsl:call-template name="footer">
      <xsl:with-param name="footer_text">
        <br/>
      </xsl:with-param>
    </xsl:call-template>

  </xsl:template>

  <xsl:template name="genome_drugnamereport_box">

    <div class="span_8_box_masonry">
      <div class="box_header span-8 last rounded-top">
        <div class="box_title"><h3 class="genome_drugnamereport_16 span-7 last">Report</h3></div>
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
    </div>

  </xsl:template>

</xsl:stylesheet>
