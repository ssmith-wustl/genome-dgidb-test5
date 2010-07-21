<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template name="genome_model_build_set" match="object[./types[./isa[@type='Genome::Model::Build::Set']]]">
    <script type="text/javascript">
      $(document).ready(function() {
        $("#build_list").tablesorter({
          // sort on sixth column, descending
          sortList: [[5,1]]
        });
      });
    </script>
    <div class="result">
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="result"><tbody><tr>
      <td>
        <!-- <div class="icon">
          <img width="32" height="32" src="/res/old/report_resources/apipe_dashboard/images/icons/model_32.png" />
        </div> -->
      </td><td>
        <div class="description">
        <h2 class="name">
          <span class="label">
            Results: <xsl:value-of select="aspect[@name='rule_display']/value" />
          </span>
          <span class="title"> 
            <xsl:value-of select="aspect[@name='rule']/object/display_name"/>
          </span>
        </h2>
      </div>
      </td></tr></tbody></table>
    </div>
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="list tablesorter" id="build_list">
      <colgroup>
        <col width="100"/>
        <col />
        <col />
        <col />
        <col />
        <col />
      </colgroup>
      <thead>
        <th>model name</th>
        <th>build id</th>
        <th>model id</th>
        <th>status</th>
        <th class="last">date scheduled</th>
        <th class="last">date completed</th>
      </thead>
      <tbody>
      <xsl:choose>
         <xsl:when test="count(aspect[@name='members']/object) > 0">
           <xsl:for-each select="aspect[@name='members']/object">
              <tr>
                <td>
                  <xsl:for-each select="aspect[@name='model']/object">
                    <xsl:call-template name="object_link"/>
                  </xsl:for-each>
                </td>
                <td class="last">
                  <xsl:call-template name="object_link">
                    <xsl:with-param name="linktext">
                      <xsl:value-of select="./@id" />
                    </xsl:with-param>
                  </xsl:call-template>
                </td>
                <td class="last">
                  <xsl:for-each select="aspect[@name='model']/object">
                    <xsl:call-template name="object_link">
                      <xsl:with-param name="linktext">
                        <xsl:value-of select="./@id" />
                      </xsl:with-param>
                    </xsl:call-template>
                  </xsl:for-each>
                </td>
                <td><xsl:attribute name="class"><xsl:text>status </xsl:text><xsl:value-of select="aspect[@name='status']/value"/></xsl:attribute>
                  <xsl:value-of select="aspect[@name='status']/value"/>
                </td>
                <td class="last">
                  <xsl:value-of select="aspect[@name='date_scheduled']/value"/> 
                </td>
                <td class="last">
                  <xsl:value-of select="aspect[@name='date_completed']/value"/> 
                </td> 
              </tr>
            </xsl:for-each>  
          </xsl:when>
          <xsl:otherwise>
            <tr>
              <td></td>
              <td colspan="5">
                <strong>No builds found matching the search criteria.</strong>
              </td>
            </tr>
          </xsl:otherwise>
        </xsl:choose>
      </tbody>
    </table>
  </xsl:template>

</xsl:stylesheet> 
