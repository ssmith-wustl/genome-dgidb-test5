<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template name="genome_sample" match="object[./types[./isa[@type='Genome::Sample']]]">
    <xsl:comment>template: /html/detail/genome_sample.xsl  match: object[./types[./isa[@type='Genome::Sample']]]</xsl:comment>

    <script type="text/javascript" src="/res/js/pkg/dataTables/media/js/jquery.dataTables.js"></script>

    <script type="text/javascript" language="javascript">
<!-- JTAL: you have no id here - but its in the params  -->

        $(document).ready(function() {

            var id = $("#sampleId").text();
            var attrUrl = "/view/genome/sample/detail.json?id=" + id;

            $('#samples').dataTable( {
                "bProcessing": false,
                "sAjaxSource": attrUrl
            });
        });

    </script>

<!--    <script type='text/javascript' src='/res/js/app/detail/genome_sample.js'></script> -->



    <span id="sampleId" style="display:none"><xsl:value-of select="/object/@id"/></span>
    <xsl:call-template name="control_bar_view"/>

    <xsl:call-template name="view_header">
      <xsl:with-param name="label_name" select="'Sample:'" />
      <xsl:with-param name="display_name" select="aspect[@name='name']/value" />
      <xsl:with-param name="icon" select="'genome_sample_32'" />
    </xsl:call-template>

    <div class="content rounded shadow">
      <div class="container">

            <!-- details for this sample -->
            <table id="samples">
                <thead>
                    <tr>
                        <th>Nomenclature</th>
                        <th>Attribute</th>
                        <th>Value</th>
                    </tr>
                </thead>
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




