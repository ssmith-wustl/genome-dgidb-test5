<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">


  <xsl:template name="genome_model_set_coverage" match="object[@type='Genome::Model::Set'] | object[@type='Genome::ModelGroup']">
    <script type="text/javascript" src="/res/js/pkg/protovis.js"></script>
    <script type="text/javascript">
      window.aSummary = [
      <xsl:for-each select="//alignment-summary/model/wingspan[@size='0']">
        <xsl:sort data-type="text" order="ascending" select="../@subject_name"/>
        <xsl:if test="total_bp"> <!-- we may get empty model nodes, which should be discarded -->
          <!-- does this model have a wingspan 500 node? -->
          <xsl:variable name="wingspan_500" select="count(../wingspan[@size='500'])"/>
          <xsl:text>//</xsl:text> wingspan_500: <xsl:value-of select="$wingspan_500"/>

          {
          "subject_name": "<xsl:value-of select="../@subject_name"/>",
          "id": <xsl:value-of select="../@id"/>,
          "total_bp": <xsl:value-of select="total_bp"/>,
          "total_unaligned_bp": <xsl:value-of select="total_unaligned_bp"/>,
          "duplicate_off_target_aligned_bp": <xsl:value-of select="duplicate_off_target_aligned_bp"/>,
          "duplicate_target_aligned_bp": <xsl:value-of select="duplicate_target_aligned_bp"/>,
          <xsl:choose>
            <!-- if we have wingspan 500 data, we'll want to show both off target and wingspan 500 off target -->
            <xsl:when test="$wingspan_500 &gt; 0">
              <xsl:variable name="unique_off_target_0" select="unique_off_target_aligned_bp"/>
              <xsl:variable name="unique_off_target_500" select="../wingspan[@size='500']/unique_off_target_aligned_bp"/>
              "unique_off_target_aligned_bp_500": <xsl:value-of select="$unique_off_target_500"/>,
              "unique_off_target_aligned_bp": <xsl:value-of select="$unique_off_target_0 - $unique_off_target_500"/>,
            </xsl:when>
            <xsl:otherwise>
              "unique_off_target_aligned_bp_500": 0,
              "unique_off_target_aligned_bp": <xsl:value-of select="unique_off_target_aligned_bp"/>,
            </xsl:otherwise>
          </xsl:choose>
          "unique_target_aligned_bp": <xsl:value-of select="unique_target_aligned_bp"/>,
          }<xsl:if test="position() != last()"><xsl:text>,</xsl:text></xsl:if>
        </xsl:if>
      </xsl:for-each>
      ];
      window.cSummary = {
      <xsl:for-each select="//coverage-summary/model">
        <xsl:sort data-type="text" order="ascending" select="@subject_name"/>
        "<xsl:value-of select="@subject_name"/>": {
        "pc_target_space_covered": {
        <xsl:for-each select="minimum_depth">
          <xsl:sort data-type="number" order="descending" select="@value"/>
          "<xsl:value-of select="@value"/>": <xsl:value-of select="pc_target_space_covered"/><xsl:if test="position() != last()"><xsl:text>,</xsl:text></xsl:if>
        </xsl:for-each>
        },
        "pc_target_space_covered_eighty_pc_breadth": {
        <xsl:for-each select="minimum_depth">
          <xsl:sort data-type="number" order="descending" select="@value"/>
          "<xsl:value-of select="@value"/>": <xsl:value-of select="pc_target_space_covered_eighty_pc_breadth"/><xsl:if test="position() != last()"><xsl:text>,</xsl:text></xsl:if>
        </xsl:for-each>
        }

        }<xsl:if test="position() != last()"><xsl:text>,</xsl:text></xsl:if>
      </xsl:for-each>
      };

    </script>


    <xsl:call-template name="control_bar_view"/>


    <xsl:variable name="display_name">
      <xsl:choose>
        <xsl:when test="@name">
          <xsl:value-of select="@name" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="@id" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:call-template name="view_header">
      <xsl:with-param name="label_name" select="'Coverage:'" />
      <xsl:with-param name="display_name" select="$display_name" />
      <xsl:with-param name="icon" select="'genome_modelgroup_32'" />
    </xsl:call-template>

    <div class="content rounded shadow">
      <div class="container">

        <div class="box rounded">
          <table border="0" cellpadding="0" cellspacing="0" class="name-value" style="margin:0;">
            <tr>
              <td class="name">Model Group Name:</td>
              <td class="value"><xsl:value-of select="@name"/></td>
            </tr>
            <tr>
              <td class="name">Models in Group:</td>
              <td class="value"><xsl:value-of select="count(//coverage-summary/model)"/></td>
            </tr>
          </table>

        </div>
        <div id="charts" style="float: left; width: 950px;">

          <table width="100%" border="0" cellpadding="0" cellspacing="0">
            <tr>
              <td style="vertical-align: top; padding-right: 10px; width: 525px;">
                <h2 class="subheader underline">coverage</h2>
                <script type="text/javascript" src="/res/js/app/genome_model_coverage_chart.js"></script>
              </td>
              <td style="vertical-align: top; width: 420px;">
                <h2 class="subheader underline">alignment</h2>
                <script type="text/javascript" src="/res/js/app/genome_model_alignment_chart.js"></script>

              </td>
            </tr>
          </table>
        </div>

        <h2 class="subheader">alignment summary</h2>
        <table class="lister" width="100%" cellspacing="0" cellpadding="0" border="0">
          <thead>
            <tr>
              <th>subject</th>
              <th>unique on-target</th>
              <th>duplicate on-target</th>
              <th>unique off-target</th>
              <th>duplicate off-target</th>
              <th>unaligned</th>
            </tr>
          </thead>
          <tbody>
            <xsl:for-each select="alignment-summary/model/wingspan[@size='0']">
              <xsl:sort select="../@subject_name" order="ascending"/>
              <tr>
                <td>
                  <xsl:value-of select="../@subject_name"/>
                </td>
                <td>
                  <xsl:value-of select="format-number(unique_target_aligned_bp, '###,###')"/>
                </td>
                <td>
                  <xsl:value-of select="format-number(duplicate_target_aligned_bp, '###,###')"/>
                </td>
                <td>
                  <xsl:value-of select="format-number(unique_off_target_aligned_bp, '###,###')"/>
                </td>
                <td>
                  <xsl:value-of select="format-number(duplicate_off_target_aligned_bp, '###,###')"/>
                </td>
                <td>
                  <xsl:value-of select="format-number(total_unaligned_bp, '###,###')"/>
                </td>
              </tr>
            </xsl:for-each>
          </tbody>
        </table>
        <h2 class="subheader">depth summary</h2>
        <table class="lister" width="100%" cellspacing="0" cellpadding="0" border="0">
          <thead>
            <tr>
              <th>subject</th>
              <xsl:for-each select="coverage-summary/minimum_depth_header">
                <xsl:sort select="@value" data-type="number" order="descending"/>
                <th>
                  <xsl:value-of select="@value"/>X
                </th>
              </xsl:for-each>
            </tr>
          </thead>
          <tbody>
            <xsl:for-each select="coverage-summary/model">
              <xsl:sort select="@subject_name" order="ascending"/>
              <tr>
                <td>
                  <xsl:value-of select="@subject_name"/>
                </td>
                <xsl:for-each select="minimum_depth">
                  <xsl:sort select="@value" data-type="number" order="descending"/>
                  <td>
                    <xsl:value-of select="pc_target_space_covered"/>%
                  </td>
                </xsl:for-each>
              </tr>
            </xsl:for-each>
          </tbody>
        </table>
        <h2 class="subheader">breadth summary (>=80%)</h2>
        <table class="lister" width="100%" cellspacing="0" cellpadding="0" border="0">
          <thead>
            <tr>
              <th>subject</th>
              <xsl:for-each select="coverage-summary/minimum_depth_header">
                <xsl:sort select="@value" data-type="number" order="descending"/>
                <th>
                  <xsl:value-of select="@value"/>X
                </th>
              </xsl:for-each>
            </tr>
          </thead>
          <tbody>
            <xsl:for-each select="coverage-summary/model">
              <xsl:sort select="@subject_name" order="ascending"/>
              <tr>
                <td>
                  <xsl:value-of select="@subject_name"/>
                </td>
                <xsl:for-each select="minimum_depth">
                  <xsl:sort select="@value" data-type="number" order="descending"/>
                  <td>
                    <xsl:value-of select="pc_target_space_covered_eighty_pc_breadth"/>%
                  </td>
                </xsl:for-each>
              </tr>
            </xsl:for-each>
          </tbody>
        </table>
      </div> <!-- end container -->
    </div> <!-- end content -->

    <xsl:call-template name="footer">
      <xsl:with-param name="footer_text">
        <br/>
      </xsl:with-param>
    </xsl:call-template>


  </xsl:template>
</xsl:stylesheet>
