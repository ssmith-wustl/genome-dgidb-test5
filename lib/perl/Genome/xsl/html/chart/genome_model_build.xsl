<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <!-- initializes the dataTable plugin for model set views -->
  <xsl:template name="genome_model_build_set_table_init" match="object[./types[./isa[@type='Genome::Model::Build']]]" mode="set_table_init">
    <xsl:comment>template: status/genome_model_build.xsl match: object[./types[./isa[@type='Genome::Model::Build']]] mode: set_table_init</xsl:comment>
    <script type="text/javascript" charset="utf-8" src="/res/js/pkg/ZeroClipboard/ZeroClipboard.js"></script> 
    <script type="text/javascript" charset="utf-8" src="/res/js/pkg/TableTools/TableTools.js"></script>
    <script type="text/javascript">
      <xsl:text disable-output-escaping="yes">
        <![CDATA[
                 $(document).ready(function() {
                 TableToolsInit.sSwfPath = "/res/js/pkg/ZeroClipboard/ZeroClipboard.swf";
                 window.setTable = $('#set').dataTable({
                 /* "sDom": 'T<"clear">lfrtip', */
                 "sScrollX": "100%",
                 "sScrollInner": "110%",
                 "bJQueryUI": true,
                 "sPaginationType": "full_numbers",
                 "bStateSave": true,
                 "iDisplayLength": 25
                 })
                 });
        ]]>
      </xsl:text>
    </script>
  </xsl:template>

  <!-- describes the columns for model build set metric views -->
  <xsl:template name="genome_model_build_set_header" match="aspect[@name='members']" mode="set_header">
  <xsl:comment>template: status/genome_model_build.xsl match: aspect[@name='members'] mode: set_header</xsl:comment>
    <tr>
      <!-- Table headers: build ID plus list of metrics of the first successful build
           Note we assume all builds have the same metrics. -->
      <th>
        build ID
      </th>
      <xsl:for-each select="object[aspect[@name='status'] = 'Succeeded'][1]">
          <xsl:for-each select="aspect[@name='metrics']/object">
            <xsl:sort select="aspect[@name='name']/value"/>
            <th>
              <xsl:value-of select="aspect[@name='name']/value" />
            </th>
          </xsl:for-each>
      </xsl:for-each>
    </tr>
  </xsl:template>

  <!-- describes the row for model set views -->
  <xsl:template name="genome_model_build_set_row" match="aspect[@name='members']" mode="set_row">
    <!-- Select objects that have metrics... note that they may have been failed builds -->
    <xsl:for-each select="object[aspect[@name='metrics'] != '']">
      <tr>
        <!-- row of build_id + metrics -->
        <td>
          <xsl:value-of select="@id" />
        </td>
        <xsl:for-each select="aspect[@name='metrics']/object">
          <xsl:sort select="aspect[@name='name']/value"/>
          <td>
            <xsl:value-of select="aspect[@name='value']/value" />
          </td>
        </xsl:for-each>
      </tr>
    </xsl:for-each>
  </xsl:template>

</xsl:stylesheet>
