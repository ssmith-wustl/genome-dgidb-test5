<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">


  <xsl:template name="genome_model_set_coverage" match="object[@type='Genome::Model::Set'] | object[@type='Genome::ModelGroup']">
    <xsl:comment>template: /html/coverage/genome_model.xsl match="object[@type='Genome::Model::Set'] | object[@type='Genome::ModelGroup']"</xsl:comment>

    <link rel="stylesheet" href="/res/js/pkg/TableTools/media/css/TableTools.css" media="screen"/>

    <script type="text/javascript" src="/res/js/pkg/protovis.js"></script>
    <script type="text/javascript" src="/res/js/pkg/dataTables/media/js/jquery.dataTables.min.js"></script>
    <script type="text/javascript" src="/res/js/pkg/TableTools/media/js/TableTools.min.js"></script>

    <script type="text/javascript" src="/res/js/app/genome_model_alignment_chart.js"></script>
    <script type="text/javascript" src="/res/js/app/genome_model_coverage_chart.js"></script>
    <script type="text/javascript" src="/res/js/app/genome_model_coverage_tables.js"></script>
    <script type="text/javascript" src="/res/js/app/genome_model_enrichment_chart.js"></script>
    <script type="text/javascript" src="/res/js/app/datatable_sort_extensions/percent.js"></script>
    <script type="text/javascript" src="/res/js/app/datatable_sort_extensions/formatted-num.js"></script>

    <script type="text/javascript">

      window.aSummary = [
      <xsl:for-each select="//alignment-summary/model/wingspan[@size='0']">
        <xsl:sort data-type="text" order="ascending" select="../@subject_name"/>
        <xsl:if test="total_bp"> <!-- we may get empty model nodes, which should be discarded -->
          <!-- does this model have a wingspan 500 node? -->
          <xsl:variable name="wingspan_500" select="count(../wingspan[@size='500'])"/>
          <xsl:text>//</xsl:text> wingspan_500: <xsl:value-of select="$wingspan_500"/>

          <!-- make sure we have essential values, otherwise assign 0 -->
          <xsl:choose>
            <xsl:when test="total_unaligned_bp">
              <xsl:variable name="total_unaligned_bp" select="total_unaligned_bp"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:variable name="total_unaligned_bp" select="'0'"/>
            </xsl:otherwise>
          </xsl:choose>

          <xsl:choose>
            <xsl:when test="duplicate_off_target_aligned_bp">
              <xsl:variable name="duplicate_off_target_aligned_bp" select="duplicate_off_target_aligned_bp"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:variable name="duplicate_off_target_aligned_bp" select="'0'"/>
            </xsl:otherwise>
          </xsl:choose>

          <xsl:choose>
            <xsl:when test="duplicate_target_aligned_bp">
              <xsl:variable name="duplicate_target_aligned_bp" select="duplicate_target_aligned_bp"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:variable name="duplicate_target_aligned_bp" select="'0'"/>
            </xsl:otherwise>
          </xsl:choose>

          {
          "subject_name": "<xsl:value-of select="../@subject_name"/>",
          "model_name": "<xsl:value-of select="../@model_name"/>",
          "id": <xsl:value-of select="../@id"/>,
          "total_bp": <xsl:value-of select="total_bp"/>,
          "total_unaligned_bp": <xsl:choose>
          <xsl:when test="total_unaligned_bp">
            <xsl:value-of  select="total_unaligned_bp"/>
          </xsl:when>
          <xsl:otherwise>
            0
          </xsl:otherwise>
        </xsl:choose>,

        "duplicate_off_target_aligned_bp": <xsl:choose>
        <xsl:when test="duplicate_off_target_aligned_bp">
          <xsl:value-of select="duplicate_off_target_aligned_bp"/>
        </xsl:when>
        <xsl:otherwise>
          0
        </xsl:otherwise>
        </xsl:choose>,

        "duplicate_target_aligned_bp": <xsl:choose>
        <xsl:when test="duplicate_target_aligned_bp">
        <xsl:value-of select="duplicate_target_aligned_bp"/>
        </xsl:when>
        <xsl:otherwise>
          0
        </xsl:otherwise>
        </xsl:choose>,
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
      window.cSummary = [
      <xsl:for-each select="//coverage-summary/model">
        <xsl:sort data-type="text" order="ascending" select="@subject_name"/>
        {
        "id": "<xsl:value-of select="@id"/>",
        "subject_name": "<xsl:value-of select="@subject_name"/>",
        "model_name": "<xsl:value-of select="@model_name"/>",
        "lane_count": "<xsl:value-of select="@lane_count"/>",
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
      ];

      window.enrichment = [
      <xsl:for-each select="//enrichment-factor/model">
        <xsl:sort data-type="text" order="ascending" select="@subject_name"/>
        {
        "id": "<xsl:value-of select="@id"/>",
        "subject_name": "<xsl:value-of select="@subject_name"/>",
        "model_name": "<xsl:value-of select="@model_name"/>",
        "enrichment_factors": {
          "unique_on_target": <xsl:value-of select="unique_on_target_enrichment_factor"/>,
          "total_on_target": <xsl:value-of select="total_on_target_enrichment_factor"/>,
          "theoretical_max": <xsl:value-of select="theoretical_max_enrichment_factor"/>
        }
        }<xsl:if test="position() != last()"><xsl:text>,</xsl:text></xsl:if>
      </xsl:for-each>
      ];


    </script>


    <xsl:call-template name="control_bar_view"/>

    <xsl:call-template name="view_header">
      <xsl:with-param name="perspective" select="$currentPerspective" />
      <xsl:with-param name="display_name" select="@display_name" />
      <!-- <xsl:with-param name="display_name" select="$displayName" /> -->
      <xsl:with-param name="icon" select="'genome_modelgroup_32'" />
    </xsl:call-template>

    <div class="content rounded shadow">
      <div class="container">

        <!-- <div class="span-24 last" style="margin-bottom: 10px;"> -->
        <!--   <div class="box rounded" style="margin: 0;"> -->
        <!--     <table border="0" cellpadding="0" cellspacing="0" class="name-value" style="margin:0;"> -->
        <!--       <tr> -->
        <!--         <td class="name">model group name:</td> -->
        <!--         <td class="value"><xsl:value-of select="@display_name"/></td> -->
        <!--       </tr> -->
        <!--       <tr> -->
        <!--         <td class="name">models in group:</td> -->
        <!--         <td class="value"><xsl:value-of select="count(//coverage-summary/model)"/></td> -->
        <!--       </tr> -->
        <!--     </table> -->

        <!--   </div> -->
        <!-- </div> -->
        <div class="span-11">
          <div class="box_header rounded-top span-11 last">
            <div class="box_title"><h3 class="nontyped">coverage</h3></div>
          </div>
          <div class="box_content rounded-bottom span-11 last">
            <div style="background: #FFF;padding: 10px;margin-bottom: 10px;border-bottom: 1px solid #C1C1B7;">
              <script type="text/javascript">
                render_coverage_chart();
              </script>
            </div>
          </div>
        </div>

        <div class="span-8">
          <div class="box_header span-8 last rounded-top">
            <div class="box_title"><h3 class="nontyped">alignment</h3></div>
          </div>
          <div class="box_content rounded-bottom span-8 last">
            <div style="background: #FFF;padding: 10px;margin-bottom: 10px;border-bottom: 1px solid #C1C1B7;">
              <script type="text/javascript">
                render_alignment_chart();
              </script>
            </div>
          </div>
        </div>

        <div class="span-5 last">
          <div class="box_header span-5 last rounded-top">
            <div class="box_title"><h3 class="nontyped">enrichment</h3></div>
          </div>
          <div class="box_content rounded-bottom span-5 last">
            <div style="background: #FFF;padding: 10px;margin-bottom: 10px;border-bottom: 1px solid #C1C1B7;">
              <script type="text/javascript">
                render_enrichment_chart();
              </script>
            </div>
          </div>
        </div>

        <div class="box_header span-24 last rounded-top">
          <div class="box_title"><h3 class="nontyped span-24 last">alignment</h3></div>
        </div>
        <div class="box_content rounded-bottom span-24 last">

          <table class="lister datatable" width="100%" cellspacing="0" cellpadding="0" border="0" id="alignment-lister">
            <thead>
              <tr>
                <th>model</th>
                <th class="right">unique on-target</th>
                <th class="right">duplicate on-target</th>
                <th class="right">unique off-target</th>
                <th class="right">duplicate off-target</th>
                <th class="right">unaligned</th>
              </tr>
            </thead>
            <tbody>
              <xsl:for-each select="alignment-summary/model/wingspan[@size='0']">
                <xsl:sort select="../@model_name" order="ascending"/>
                <xsl:sort select="../@lane_count" order="ascending"/>
                <tr>
                  <td>
                    <xsl:value-of select="../@model_name"/> (<xsl:value-of select="../@lane_count"/> lane<xsl:if test="../@lane_count &gt; 1">s</xsl:if>)
                  </td>
                  <td class="right">
                    <xsl:value-of select="format-number(unique_target_aligned_bp, '###,###')"/>
                  </td>
                  <td class="right">
                    <xsl:value-of select="format-number(duplicate_target_aligned_bp, '###,###')"/>
                  </td>
                  <td class="right">
                    <xsl:value-of select="format-number(unique_off_target_aligned_bp, '###,###')"/>
                  </td>
                  <td class="right">
                    <xsl:value-of select="format-number(duplicate_off_target_aligned_bp, '###,###')"/>
                  </td>
                  <td class="right">
                    <xsl:value-of select="format-number(total_unaligned_bp, '###,###')"/>
                  </td>
                </tr>
              </xsl:for-each>
            </tbody>
          </table>
        </div>

        <div class="box_header span-24 last rounded-top">
          <div class="box_title"><h3 class="nontyped span-24 last">coverage depth</h3></div>
        </div>
        <div class="box_content rounded-bottom span-24 last">
          <table class="lister datatable" width="100%" cellspacing="0" cellpadding="0" border="0" id="coverage-depth-lister">
            <thead>
              <tr>
                <th>model</th>
                <xsl:for-each select="coverage-summary/minimum_depth_header">
                  <xsl:sort select="@value" data-type="number" order="descending"/>
                  <th class="right">
                    <xsl:value-of select="@value"/>X
                  </th>
                </xsl:for-each>
              </tr>
            </thead>
            <tbody>
              <xsl:for-each select="coverage-summary/model">
                <xsl:sort select="@model_name" order="ascending"/>
                <xsl:sort select="../@lane_count" order="ascending"/>
                <tr>
                  <td>
                    <xsl:value-of select="@model_name"/> (<xsl:value-of select="@lane_count"/> lane<xsl:if test="@lane_count &gt; 1">s</xsl:if>)
                  </td>
                  <xsl:for-each select="minimum_depth">
                    <xsl:sort select="@value" data-type="number" order="descending"/>
                    <td class="right">
                      <xsl:value-of select="pc_target_space_covered"/>%
                    </td>
                  </xsl:for-each>
                </tr>
              </xsl:for-each>
            </tbody>
          </table>
        </div>

        <div class="box_header span-24 last rounded-top">
          <div class="box_title"><h3 class="nontyped span-24 last">coverage breadth (&gt;= 80%)</h3></div>
        </div>
        <div class="box_content rounded-bottom span-24 last">
          <table class="lister datatable" width="100%" cellspacing="0" cellpadding="0" border="0" id="coverage-summary-lister">
            <thead>
              <tr>
                <th>model</th>
                <xsl:for-each select="coverage-summary/minimum_depth_header">
                  <xsl:sort select="@value" data-type="number" order="descending"/>
                  <th class="right">
                    <xsl:value-of select="@value"/>X
                  </th>
                </xsl:for-each>
              </tr>
            </thead>
            <tbody>
              <xsl:for-each select="coverage-summary/model">
                <xsl:sort select="@model_name" order="ascending"/>
                <xsl:sort select="../@lane_count" order="ascending"/>

                <tr>
                  <td>
                    <xsl:value-of select="@model_name"/> (<xsl:value-of select="@lane_count"/> lane<xsl:if test="@lane_count &gt; 1">s</xsl:if>)
                  </td>
                  <xsl:for-each select="minimum_depth">
                    <xsl:sort select="@value" data-type="number" order="descending"/>
                    <td class="right">
                      <xsl:value-of select="pc_target_space_covered_eighty_pc_breadth"/>%
                    </td>
                  </xsl:for-each>
                </tr>
              </xsl:for-each>
            </tbody>
          </table>
        </div>

        <div class="box_header span-24 last rounded-top">
          <div class="box_title"><h3 class="nontyped span-24 last">enrichment factor</h3></div>
        </div>
        <div class="box_content rounded-bottom span-24 last">
          <table class="lister datatable" width="100%" cellspacing="0" cellpadding="0" border="0" id="enrichment-factor-lister">
            <thead>
              <tr>
                <th>model</th>
                <th class="right">unique on-target</th>
                <th class="right">total on-target</th>
                <th class="right">theoretical max</th>
              </tr>
            </thead>
            <tbody>
              <xsl:for-each select="enrichment-factor/model">
                <xsl:sort select="@model_name" order="ascending"/>
                <xsl:sort select="../@lane_count" order="ascending"/>
                <tr>
                  <td>
                    <xsl:value-of select="@model_name"/> (<xsl:value-of select="@lane_count"/> lane<xsl:if test="@lane_count &gt; 1">s</xsl:if>)
                  </td>
                  <td class="right">
                    <xsl:value-of select="unique_on_target_enrichment_factor"/>
                  </td>
                  <td class="right">
                    <xsl:value-of select="total_on_target_enrichment_factor"/>
                  </td>
                  <td class="right">
                    <xsl:value-of select="theoretical_max_enrichment_factor"/>
                  </td>
                </tr>
              </xsl:for-each>
            </tbody>
          </table>
        </div>


      </div> <!-- end container -->
    </div> <!-- end content -->

    <xsl:call-template name="footer">
      <xsl:with-param name="footer_text">
        <br/>
      </xsl:with-param>
    </xsl:call-template>


  </xsl:template>
</xsl:stylesheet>
