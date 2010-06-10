<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">


  <xsl:template name="genome_modelgroup" match="object[@type='Genome::ModelGroup']">
    <h2 class="page_title build_icon">Coverage Metrics for Model Group <xsl:value-of select="@id"/></h2>
    <table border="0" cellpadding="0" cellspacing="0" class="info_table">
      <tr>
        <td class="label">Model Group Name:</td>
        <td class="value"><xsl:value-of select="@name"/></td>
      </tr>
    </table>
    <h2>alignment summary</h2>
    <table class="list" width="100%" cellspacing="0" cellpadding="0" border="0">
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
        <xsl:for-each select="alignment-summary/model">
          <xsl:sort select="@subject_name" order="ascending"/>
          <tr>
            <td>
              <xsl:value-of select="@subject_name"/>
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
    <h2>depth summary</h2>
    <table class="list" width="100%" cellspacing="0" cellpadding="0" border="0">
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
    <h2>breadth >=80% summary</h2>
    <table class="list" width="100%" cellspacing="0" cellpadding="0" border="0">
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
  </xsl:template>
</xsl:stylesheet>
