<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <!-- full page display for population group -->
  <xsl:template name="genome_populationgroup" match="object[./types[./isa[@type='Genome::PopulationGroup']]]">
    <xsl:call-template name="view_header">
      <xsl:with-param name="label_name" select="'Population Group:'" />
      <xsl:with-param name="display_name">
        <xsl:choose>
          <xsl:when test="string(normalize-space(aspect[@name='common_name']/value))">
            <xsl:value-of select="aspect[@name='common_name']/value"/>
          </xsl:when>
          <xsl:when test="string(normalize-space(aspect[@name='name']/value))">
            <xsl:value-of select="normalize-space(aspect[@name='name']/value)"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="normalize-space(display_name)"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:with-param>
      <xsl:with-param name="icon" select="'genome_populationgroup_32'" />
    </xsl:call-template>

    <div class="content rounded shadow">
      <div class="container">
        <div id="objects" class="span-24 last">

          <!-- details for this PopulationGroup -->
          <div class="span_8_box_masonry">
            <div class="box_header span-8 last rounded-top">
              <div class="box_title"><h3 class="nontyped span-7 last">Population Group Attributes</h3></div>
              <div class="box_button">

              </div>
            </div>

            <div class="box_content rounded-bottom span-8 last">
              <table class="name-value">
                <tbody>
                  <tr>
                    <td class="name">Display Name:
                    </td>
                    <td class="value">
                      <xsl:choose>
                        <xsl:when test="string(normalize-space(display_name))">
                          <xsl:value-of select="normalize-space(display_name)"/>
                        </xsl:when>
                        <xsl:otherwise>
                          --
                        </xsl:otherwise>
                      </xsl:choose>
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
                    <td class="name">Common Name:
                    </td>
                    <td class="value">
                      <xsl:choose>
                        <xsl:when test="string(normalize-space(aspect[@name='common_name']/value))">
                          <xsl:value-of select="normalize-space(aspect[@name='common_name']/value)"/>
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

          <xsl:for-each select="aspect[@name='members']/object">
            <xsl:call-template name="genome_individual_box"/>
          </xsl:for-each>
        </div> <!-- end .masonry -->
      </div> <!-- end container -->
    </div> <!-- end content -->

    <xsl:call-template name="footer">
      <xsl:with-param name="footer_text">
        <br/>
      </xsl:with-param>
    </xsl:call-template>


  </xsl:template>

</xsl:stylesheet>