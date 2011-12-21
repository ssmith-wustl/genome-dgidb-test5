<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template name="genome_sys_user" match="object[./types[./isa[@type='Genome::Sys::User']]]">
    <xsl:comment>template: /html/status/genome_sys_user.xsl  match: object[./types[./isa[@type='Genome::Sys::User']]]</xsl:comment>

    <xsl:call-template name="control_bar_view"/>

    <xsl:call-template name="view_header">
      <xsl:with-param name="label_name" select="'User'" />
      <xsl:with-param name="display_name" select="aspect[@name='username']/value" />
      <xsl:with-param name="icon" select="'genome_sys_user_32'" />
    </xsl:call-template>

    <script type="text/javascript" src="/res/js/app/genome_projectbox.js"></script>
    <script>
       $(document).ready(function() {
            updateProjectBox("adukes");
       });
    </script>

    <div class="content rounded shadow">
      <div class="project_container container">

          <!-- details for user's projects -->

            <div id="myProjectBox" class="project_box rounded-right">
                <h4 style="float: left" id="myProjectsCount"></h4>
                <div style="margin: 2px 0px 0px 10px; float: left; color: red" id="loadingStatus"></div>
                <br/>

                <ul id="projectBox"> </ul>

            </div>


      </div> <!-- end container -->
    </div> <!-- end content -->

  </xsl:template>

</xsl:stylesheet>
