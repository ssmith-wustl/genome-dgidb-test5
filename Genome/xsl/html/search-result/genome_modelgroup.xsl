<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template name="genome_modelgroup" match="object[./types[./isa[@type='Genome::ModelGroup']]]">
    <div class="result">
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="result"><tbody><tr>
      <td>
        <div class="icon">
          <xsl:call-template name="object_link">
             <xsl:with-param name="linktext">
              <img width="32" height="32" src="/resources/report_resources/apipe_dashboard/images/icons/modelgroup_32.png" />
            </xsl:with-param>
          </xsl:call-template>
        </div>
      </td><td>
        <div class="description">
        <h2 class="name">
          <span class="label">
            Model Group:
          </span>
          <span class="title"> 
            <xsl:call-template name="object_link" />
          </span>
        </h2>
        <p>
          <xsl:for-each select="aspect[@name='convergence_model']/object">
            <xsl:call-template name="object_link">
              <xsl:with-param name="linktext" select="'convergence model'" />
            </xsl:call-template>
            (<xsl:choose>
              <xsl:when test="aspect[@name='last_complete_build']/object">
                <xsl:for-each select="aspect[@name='last_complete_build']/object">
                  <xsl:call-template name="object_link">
                    <xsl:with-param name="linktext" select="'last succeeded build'" />
                  </xsl:call-template>
                </xsl:for-each>
              </xsl:when>
              <xsl:otherwise>
                [No succeeded builds.]
              </xsl:otherwise>
            </xsl:choose>)
          </xsl:for-each>
        </p>
        <p class="blurb"> 
          Members: <xsl:for-each select="aspect[@name='models']/object">
            <xsl:value-of select="aspect[@name='name']/value"/>
          </xsl:for-each>
        </p>
      </div>
      </td></tr></tbody></table>
    </div>
  </xsl:template>

</xsl:stylesheet> 