<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
xmlns:rest="urn:rest">

  <xsl:template name="workflow_operation_instanceexecution" match="object[./types[./isa[@type='Workflow::Operation::InstanceExecution']]]">

    <xsl:if test="count(aspect) > 0">
      <div class="aspects">
        <table class="name-value" cellpadding="0" cellspacing="0" border="0">
          <tbody>
            <xsl:for-each select="aspect">
              <tr>
                <td class="name">
                  <xsl:value-of select="@name"/>:
                </td>
                <xsl:if test="@name='stderr' or @name='stdout'">
                  <xsl:variable name="path" select="."/>
                  <td class="value"><a><xsl:attribute name="href"><xsl:text>https://gscweb.gsc.wustl.edu</xsl:text>
                  <xsl:value-of select="$path"/>
                  </xsl:attribute><xsl:value-of select="$path"/></a>
                  </td>
                </xsl:if>
                <xsl:if test="@name!='stderr' and @name!='stdout'">
                  <td class="value"><xsl:apply-templates/></td>
                </xsl:if>
              </tr>
            </xsl:for-each>
          </tbody>
        </table>
      </div>
    </xsl:if>

  </xsl:template>

</xsl:stylesheet>

