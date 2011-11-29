<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template name="genome_druggablegene_druggeneinteractionreport_set" match="object[./types[./isa[@type='Genome::DruggableGene::DrugGeneInteractionReport::Set']]]">

    <script type='text/javascript' src='/res/js/pkg/boxy/javascripts/jquery.boxy.js'></script>
    <link rel="stylesheet" href="/res/js/pkg/boxy/stylesheets/boxy.css" type="text/css" />
    <script type='text/javascript' src='/res/js/app/genome_model_build_list.js'></script>

    <xsl:call-template name="control_bar_view"/>

    <xsl:call-template name="view_header">
      <xsl:with-param name="display_name" select="/object/aspect[@name='members']/object/display_name" />
      <xsl:with-param name="icon" select="'genome_druggeneinteractionreport_32'" />
    </xsl:call-template>

    <div class="content rounded shadow">
        <xsl:for-each select="aspect[@name='members']/object">
            <xsl:call-template name='DrugGeneInteractionReportDetail'/>
        </xsl:for-each>
    </div> <!-- end content -->

    <xsl:call-template name="footer">
      <xsl:with-param name="footer_text">
        <br/>
      </xsl:with-param>
    </xsl:call-template>

  </xsl:template>
</xsl:stylesheet>
