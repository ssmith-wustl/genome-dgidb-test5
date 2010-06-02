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
     <!--This causes some weird formating issues
         <tr>
        <td class="label">Target Region Set Name:</td>
        <td class="value"><xsl:value-of select="target_region_set_names"/></td>
     </tr>
         -->
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
          <th class="last">total target aligned BP</th>
          <th class="last">% target aligned</th>
          <th class="last">unique target aligned BP</th>
          <th class="last">duplicate target aligned BP</th>
          <th class="last">% duplicate target aligned</th>
        </tr>
      </thead>
      <tbody>
        <xsl:for-each select="alignment-summary/wingspan">
          <xsl:variable name="total_bp" select="total_bp"/>
          <xsl:variable name="total_aligned_bp" select="total_aligned_bp"/>
          <xsl:variable name="total_duplicate_bp" select="total_duplicate_bp"/>
          <xsl:variable name="pc_aligned" select="($total_aligned_bp div $total_bp) * 100"/>
          <xsl:variable name="pc_duplicates" select="($total_duplicate_bp div $total_aligned_bp) * 100"/>
          <xsl:variable name="total_target_aligned_bp" select="total_target_aligned_bp"/>
          <xsl:variable name="pc_target_aligned" select="($total_target_aligned_bp div $total_aligned_bp) * 100"/>
          <xsl:variable name="unique_target_aligned_bp" select="unique_target_aligned_bp"/>
          <xsl:variable name="duplicate_target_aligned_bp" select="duplicate_target_aligned_bp"/>
          <xsl:variable name="pc_duplicate_target_aligned" select="($duplicate_target_aligned_bp div $total_target_aligned_bp) * 100"/>
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
            <td class="last">
              <xsl:value-of select="format-number($total_target_aligned_bp, '###,###')"/>
            </td>
            <td class="last">
              <xsl:value-of select="format-number($pc_target_aligned, '###.000')"/>%
            </td>
            <td class="last">
              <xsl:value-of select="format-number($unique_target_aligned_bp, '###,###')"/>
            </td>
            <td class="last">
              <xsl:value-of select="format-number($duplicate_target_aligned_bp, '###,###')"/>
            </td>
            <td class="last">
              <xsl:value-of select="format-number($pc_duplicate_target_aligned, '###.000')"/>%
            </td>
          </tr>
        </xsl:for-each>
      </tbody>
    </table>

    <h2>depth summary</h2>
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
          <th class="last">targets</th>
          <th class="last">targets touched</th>
          <th class="last">% targets touched</th>
          <th class="last">target BP</th>
          <th class="last">covered BP</th>
          <th class="last">% target space covered</th>
        </tr>
      </thead>
      <tbody>
        <xsl:for-each select="coverage-stats-summary/wingspan/minimum_depth">
          <xsl:sort select="@value" data-type="number" order="ascending"/>
          <xsl:variable name="targets" select="targets"/>
          <xsl:variable name="touched" select="touched"/>
          <xsl:variable name="pc_touched" select="($touched div $targets) * 100"/>
          <xsl:variable name="target_base_pair" select="target_base_pair"/>
          <xsl:variable name="covered_base_pair" select="covered_base_pair"/>
          <xsl:variable name="pc_target_space_covered" select="($covered_base_pair div $target_base_pair) * 100"/>
          <tr>
            <td>
              <xsl:value-of select="@value"/>
            </td>
            <td class="last">
              <xsl:value-of select="format-number($targets,'###,###')"/>
            </td>
            <td class="last">
              <xsl:value-of select="format-number($touched,'###,###')"/>
            </td>
            <td class="last">
              <xsl:value-of select="format-number($pc_touched,'###.000')"/>%
            </td>
            <td class="last">
              <xsl:value-of select="format-number($target_base_pair,'###,###')"/>
            </td>
            <td class="last">
              <xsl:value-of select="format-number($covered_base_pair,'###,###')"/>
            </td>
            <td class="last">
              <xsl:value-of select="format-number($pc_target_space_covered,'###.000')"/>%
            </td>
            
          </tr>
        </xsl:for-each>
      </tbody>
    </table>
    <h2>depth with breadth(>=80%) summary</h2>
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
          <th class="last">targets</th>
          <th class="last">targets touched</th>
          <th class="last">% targets touched</th>
          <th class="last">target BP</th>
          <th class="last">covered BP</th>
          <th class="last">% target space covered</th>
          
        </tr>
      </thead>
      <tbody>
        <xsl:for-each select="coverage-stats-summary/wingspan/minimum_depth">
          <xsl:sort select="@value" data-type="number" order="ascending"/>
          <xsl:variable name="targets" select="targets"/>
          <xsl:variable name="targets_eighty_pc_breadth" select="targets_eighty_pc_breadth"/>
          <xsl:variable name="pc_targets_eighty_pc_breadth" select="($targets_eighty_pc_breadth div $targets) * 100"/>
          <xsl:variable name="target_base_pair" select="target_base_pair"/>
          <xsl:variable name="covered_base_pair_eighty_pc_breadth" select="covered_base_pair_eighty_pc_breadth"/>
          <xsl:variable name="pc_target_covered_base_pair_eighty_pc_breadth" select="($covered_base_pair_eighty_pc_breadth div $target_base_pair) *100"/>
          <tr>
            <td>
              <xsl:value-of select="@value"/>
            </td>
            <td class="last">
              <xsl:value-of select="format-number($targets,'###,###')"/>
            </td>
            <td class="last">
              <xsl:value-of select="format-number($targets_eighty_pc_breadth,'###,###')"/>
            </td>
            <td class="last">
              <xsl:value-of select="format-number($pc_targets_eighty_pc_breadth,'###.000')"/>%
            </td>
            <td class="last">
              <xsl:value-of select="format-number($target_base_pair,'###,###')"/>
            </td>
            <td class="last">
              <xsl:value-of select="format-number($covered_base_pair_eighty_pc_breadth,'###,###')"/>
            </td>
            <td class="last">
              <xsl:value-of select="format-number($pc_target_covered_base_pair_eighty_pc_breadth,'###.000')"/>%
            </td>
          </tr>
        </xsl:for-each>
      </tbody>
    </table>
  </xsl:template>
</xsl:stylesheet>
