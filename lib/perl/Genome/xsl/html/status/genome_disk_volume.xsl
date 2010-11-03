<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:str="http://xsltsl.org/string">

  <xsl:template name="genome_disk_volume" match="object[./types[./isa[@type='Genome::Disk::Volume']]]">
    <xsl:comment>template: status/genome_disk_volume.xsl match: object[./types[./isa[@type='Genome::Disk::Volume']]]</xsl:comment>
    <xsl:call-template name="control_bar_view"/>

    <xsl:call-template name="view_header">
      <xsl:with-param name="label_name" select="'Disk Volume:'" />
      <xsl:with-param name="display_name" select="aspect[@name='mount_path']/value" />
      <xsl:with-param name="icon" select="'genome_disk_volume_32'" />
    </xsl:call-template>

    <div class="content rounded shadow">
      <div class="container">
        <div id="objects" class="span-24 last">

          <div class="span_8_box_masonry">
            <div class="box_header span-8 last rounded-top">
              <div class="box_title"><h3 class="nontyped span-7 last">Summary</h3></div>
              <div class="box_button">

              </div>
            </div>

            <div class="box_content rounded-bottom span-8 last">
              <table class="name-value">
                <tbody>

                  <tr>
                    <td class="name">Status:</td>
                    <td class="value"><xsl:value-of select="aspect[@name='disk_status']/value"/></td>
                  </tr>

                  <tr>
                    <td class="name">Can Allocate:</td>
                    <td class="value"><xsl:value-of select="aspect[@name='can_allocate']/value"/></td>
                  </tr>

                  <tr>
                    <td class="name">Unallocated (kb):</td>
                    <td class="value"><xsl:value-of select="aspect[@name='unallocated_kb']/value"/></td>
                  </tr>

                  <tr>
                    <td class="name">Total (kb):</td>
                    <td class="value"><xsl:value-of select="aspect[@name='total_kb']/value"/></td>
                  </tr>

                  <tr>
                    <td class="name">Disk Group:</td>
                    <td class="value"><xsl:value-of select="aspect[@name='disk_group_names']/value"/></td>
                  </tr>

                </tbody>
              </table>
            </div>

                <xsl:call-template name="genome_disk_volume_table"></xsl:call-template>
          </div>


        </div> <!-- end .objects -->
      </div> <!-- end container -->
    </div> <!-- end content -->

    <xsl:call-template name="footer">
      <xsl:with-param name="footer_text">
        <br/>
      </xsl:with-param>
    </xsl:call-template>

  </xsl:template>

  <xsl:template name="genome_disk_volume_table">
    <xsl:comment>template: status/genome_disk_volume.xsl name: genome_disk_volume_table</xsl:comment>
    <div class="generic_lister">
      <div class="box_header span-24 last rounded-top">
        <div class="box_title"><h3 class="nontyped span-24 last">Allocations</h3></div>
      </div>
      <div class="box_content rounded-bottom span-24 last">
        <table class="lister">
          <thead>
            <tr>
              <th>build id</th>
              <th>genome model class</th>
              <th>build status</th>
              <th>requested (kb)</th>
              <th>absolute path</th>
            </tr>
          </thead>
          <tbody>

            <xsl:for-each select="/object/aspect[@name='allocations']/object">
                <xsl:sort select="aspect[@name='owner_id']/value" data-type="number" order="ascending"/>
                <xsl:call-template name="genome_disk_volume_table_row"/>
            </xsl:for-each>
          </tbody>
        </table>
      </div> <!-- end box_content -->
    </div> <!-- end generic lister -->

  </xsl:template>

  <xsl:template name="genome_disk_volume_table_row">
    <xsl:comment>template: status/genome_disk_volume.xsl name: genome_disk_volume_table_row</xsl:comment>
    <tr>
      <td><xsl:value-of select="aspect[@name='owner_id']/value"/></td>
      <td> <xsl:call-template name="str:substring-after-last">
            <xsl:with-param name="text"> <xsl:value-of select="aspect[@name='owner_class_name']/value"/> </xsl:with-param>
            <xsl:with-param name="chars"> <xsl:text>Genome::Model::</xsl:text> </xsl:with-param>
           </xsl:call-template>
      </td>
      <td> <xsl:value-of select="aspect[@name='build_status']/value"/> </td>
      <td> <xsl:value-of select="aspect[@name='kilobytes_requested']/value"/> </td>
      <td> <xsl:value-of select="aspect[@name='kilobytes_used']/value"/> </td>
      <td> <a> 
            <xsl:variable name="absolute_path" select="aspect[@name='absolute_path']/value"/>
            <xsl:attribute name="href"> 
                <xsl:value-of select="$absolute_path"/>
            </xsl:attribute> 
            <xsl:value-of select="substring($absolute_path,1,30)"/>...
            </a> 
       </td>
    </tr>
  </xsl:template>

</xsl:stylesheet>
