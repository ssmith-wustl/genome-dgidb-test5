<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">


  <xsl:template name="genome_model_build_referencealignment" match="object[@type='Genome::Model::Build::ReferenceAlignment::Solexa']">
    <h2 class="page_title build_icon">Coverage Metrics for Build  <xsl:value-of select="@id"/></h2>
    <table border="0" cellpadding="0" cellspacing="0" class="info_table">
      <tr>
        <td class="label">Region of Interest Set Name:</td>
        <td class="value"><xsl:value-of select="region_of_interest_set_name"/></td>
      </tr>
<!--      <tr>
        <td class="label">Target Regions Set Names:</td>
        <td class="value"><xsl:value-of select="target_region_set_names"/></td>
      </tr> -->
    </table>

    <h2>aligned reads</h2>
    <table class="list" width="100%" cellspacing="0" cellpadding="0" border="0">
      <!-- <colgroup> -->
      <!--   <col width="40%"/> -->
      <!--   <col/> -->
      <!--   <col/> -->
      <!--   <col/> -->
      <!--   <col/> -->
      <!-- </colgroup> -->
      <thead>
        <tr>
          <th>wingspan</th>
          <th class="last">total BP</th>
          <th class="last">total aligned BP</th>
          <th class="last">% aligned</th>
          <th class="last">total duplicates</th>
          <th class="last">% duplicates</th>
        </tr>
      </thead>
      <tbody>
        <xsl:for-each select="alignment-summary/wingspan">
          <xsl:variable name="total_bp" select="total_bp"/>
          <xsl:variable name="total_aligned_bp" select="total_aligned_bp"/>
          <xsl:variable name="total_duplicate_bp" select="total_duplicate_bp"/>
          <xsl:variable name="pc_aligned" select="($total_aligned_bp div $total_bp) * 100"/>
          <xsl:variable name="pc_duplicates" select="($total_duplicate_bp div $total_aligned_bp) * 100"/>
          <tr>
            <td>
              <xsl:value-of select="@value"/>
            </td>
            <td class="last">
              <xsl:value-of select="format-number($total_bp, '###,###')"/>
            </td>
            <td class="last">
              <xsl:value-of select="format-number($total_aligned_bp, '###,###')"/>
            </td>
            <td class="last">
              <xsl:value-of select="format-number($pc_aligned, '###.000')"/>%
            </td>
            <td class="last">
              <xsl:value-of select="format-number($total_duplicate_bp, '###,###')"/>
            </td>
            <td class="last">
              <xsl:value-of select="format-number($pc_duplicates, '###.000')"/>%
            </td>
          </tr>
        </xsl:for-each>
      </tbody>
    </table>

    <h2>depth and breadth summary</h2>
    <table class="list" width="100%" cellspacing="0" cellpadding="0" border="0">
      <!-- <colgroup> -->
      <!--   <col width="40%"/> -->
      <!--   <col/> -->
      <!--   <col/> -->
      <!--   <col/> -->
      <!--   <col/> -->
      <!-- </colgroup> -->
      <thead>
        <tr>
          <th>minimum depth</th>
          <th class="last">% target space covered</th>
          <th class="last">% targets 80% breadth</th>
        </tr>
      </thead>
      <tbody>
        <xsl:for-each select="coverage-stats-summary/wingspan/minimum_depth">
          <xsl:sort select="@value" data-type="number" order="ascending"/>
          <tr>
            <td>
              <xsl:value-of select="@value"/>
            </td>
            <td class="last">
              <xsl:value-of select="pc_touched"/>%
            </td>
            <td class="last">
              <xsl:value-of select="pc_targets_eighty_pc_breadth"/>%
            </td>
          </tr>
        </xsl:for-each>
      </tbody>
    </table>

  </xsl:template>
</xsl:stylesheet>