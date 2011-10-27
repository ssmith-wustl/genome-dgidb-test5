<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">


  <xsl:template name="genome_nomenclature_set" match="object[./types[./isa[@type='UR::Object::Set']]]">

    <xsl:call-template name="control_bar_view"/>

    <xsl:call-template name="set_header">
      <xsl:with-param name="display_name" select="'Listing Nomenclatures'" />
    </xsl:call-template>

    <div class="content rounded shadow">
      <div class="container">

        <hr class="space" style="height: 10px; margin: 0;"/>

        <div class="span-24 last">
          <table id="myTable" width="100%" cellpadding="0" cellspacing="0" border="0" class="dataTable">
            <thead>
             <th>Nomenclature Name</th>
             <th>Template</th>
            </thead>
            <tbody>
              <xsl:for-each select="aspect[@name='members']/object">
              <tr>
              <td>
                <a><xsl:attribute name="href">/view/genome/nomenclature/set/create.html#id=<xsl:value-of select='@id'/></xsl:attribute>
                <xsl:value-of select="display_name"/></a>
              </td>
              <td>
                Get: 
                <a><xsl:attribute name="href">/view/genome/nomenclature/detail.xls?id=<xsl:value-of select='@id'/></xsl:attribute>Excel</a>
                |
                <a><xsl:attribute name="href">/view/genome/nomenclature/detail.csv?id=<xsl:value-of select='@id'/></xsl:attribute>CSV</a>
              </td>
              </tr>
              </xsl:for-each>
            </tbody>
          </table>
        </div>
      </div> <!-- end container -->
    </div> <!-- end content -->

  <script type="text/javascript">
                 $(document).ready(function(){
                 $('#myTable').dataTable({
                 "sScrollX": "100%",
                 "sScrollInner": "110%",
                 "bJQueryUI": true,
                 "sPaginationType": "full_numbers",
                 "bStateSave": true,
                 "iDisplayLength": 25
                 });
                 }
                 );
    </script>

    <xsl:call-template name="footer">
      <xsl:with-param name="footer_text">
        <br/>
      </xsl:with-param>
    </xsl:call-template>

  </xsl:template>

</xsl:stylesheet>
