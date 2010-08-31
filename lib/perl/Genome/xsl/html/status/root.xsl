<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output
      method="xml"
      omit-xml-declaration="yes"
      doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"
      doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
      indent="yes"/>

  <xsl:strip-space elements="*"/>

  <!-- BASE PAGE TEMPLATE -->

  <xsl:template match="/">
    <xsl:comment>template: status/root.xsl:match "/"</xsl:comment>

    <xsl:variable name="title">
      <xsl:choose>
        <xsl:when test="/object">
          <xsl:value-of select="/object/label_name" />: <xsl:value-of select="/object/display_name" /> - Status
        </xsl:when>
        <xsl:otherwise>
          Status
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <html>
      <head>
        <title><xsl:value-of select="normalize-space($title)"/></title>
        <link rel="shortcut icon" href="/res/img/gc_favicon.png" type="image/png" />

        <!-- blueprint CSS -->
        <link rel="stylesheet" href="/res/css/blueprint/screen.css" type="text/css" media="screen, projection"/>
        <link rel="stylesheet" href="/res/css/blueprint/print.css" type="text/css" media="print"/>
        <!--[if lt IE 8]><link rel="stylesheet" href="/css/blueprint/ie.css" type="text/css" media="screen, projection"><![endif]-->

        <!-- report styles  -->
        <link rel="stylesheet" href="/res/css/master.css" type="text/css" media="screen, projection"/>
        <link rel="stylesheet" href="/res/css/buttons.css" type="text/css" media="screen, projection"/>
        <link rel="stylesheet" href="/res/css/icons.css" type="text/css" media="screen, projection"/>
        <link rel="stylesheet" href="/res/css/forms.css" type="text/css" media="screen, projection"/>

        <!-- jquery and jquery UI -->
        <link type="text/css" href="/res/js/pkg/jquery-ui-1.8.1.custom/css/gsc-theme/jquery-ui-1.8.1.custom.css" rel="stylesheet" />
        <link href="/res/css/jquery-ui-overrides.css" type="text/css" rel="stylesheet" media="screen, projection"/>
        <script type="text/javascript" src="/res/js/pkg/jquery.js"></script>
        <script type="text/javascript" src="/res/js/pkg/jquery-ui.js"></script>

        <!-- jquery.masonry to arrange the object info boxes-->
        <script type="text/javascript" src="/res/js/pkg/jquery.masonry.min.js"></script>

        <!-- jquery.hoverIntent - a better hover() function for jQuery -->
        <script type="text/javascript" src="/res/js/pkg/jquery.hoverIntent.min.js"></script>


        <!-- jquery.spinner for easy creation of loading spinners -->
        <!-- <script type="text/javascript" src="/res/js/pkg/spinner/jquery.spinner.js"></script> -->

        <!-- jquery.dataTables for spiffy feature-laden lists -->
        <script type="text/javascript" src="/res/js/pkg/dataTables/media/js/jquery.dataTables.min.js"></script>
        <link rel="stylesheet" href="/res/css/dataTables.css" type="text/css" media="screen, projection"/>

        <!-- fire up spiffy UI scripts-->
        <script type="text/javascript" src="/res/js/app/ui-init.js"></script>

        <script type="text/javascript">
          <![CDATA[
                   (function($) {
                   var cache = [];
                   // Arguments are image paths relative to the current page.
                   $.preLoadImages = function() {
                   var args_len = arguments.length;
                   for (var i = args_len; i--;) {
                   var cacheImage = document.createElement('img');
                   cacheImage.src = arguments[i];
                   cache.push(cacheImage);
                   }
                   }
                   })(jQuery)

// $(document).ready(function() {
//$.preLoadImages("/res/img/spinner.gif");

//$("#ajax_status")
//.addClass('success')
//.bind("ajaxSend", function(){
//$(this).removeClass('success error').addClass('loading').html('Loading').show();
//})
//.bind("ajaxSuccess", function(){
//$(this).removeClass('loading').addClass('success').html('Success').hide('slow');
//})
//.bind("ajaxError", function(){
//$(this).removeClass('loading').addClass('error').html('Error');
//})
//.hide();
//});
          ]]>
        </script>
        <script language="javascript" type="text/javascript">
          <![CDATA[
                   $(document).ready(function(){

//Hide (Collapse) the toggle containers on load
$(".toggle_container").hide();

//Slide up and down on click
$("span.trigger").click(function(){

$(this).parent().next(".toggle_container").slideToggle("slow");
});

});
          ]]>
        </script>
      </head>

      <body>
        <div class="page">

          <xsl:apply-templates/>

        </div> <!-- end of .page -->
      </body>
    </html>

  </xsl:template>

  <!--
      #############################################
      PAGE COMPONENT TEMPLATES
      #############################################
  -->

  <!-- page header for apps -->
  <xsl:template name="app_header">
    <xsl:param name="app_name"/>
    <xsl:param name="icon"/>

    <xsl:comment>template: status/root.xsl:app_header</xsl:comment>

    <div class="header rounded-top gradient-grey">
      <div class="container">
        <div><xsl:attribute name="class">title span-24 last <xsl:copy-of select="$icon"/></xsl:attribute>
        <h1><xsl:value-of select="$app_name"/></h1>
        </div>
      </div>
    </div>
  </xsl:template>


  <!-- page header for views -->
  <xsl:template name="view_header">
    <xsl:param name="label_name"/>
    <xsl:param name="display_name"/>
    <xsl:param name="icon"/>

    <xsl:comment>template: status/root.xsl:view_header</xsl:comment>

    <div class="header rounded-bottom gradient-grey shadow">
      <div class="container">
        <div><xsl:attribute name="class">title span-24 last <xsl:copy-of select="$icon"/></xsl:attribute>
        <h1><xsl:value-of select="$label_name"/><xsl:text> </xsl:text> <xsl:value-of select="$display_name"/></h1>
        </div>
      </div>
    </div>

  </xsl:template>

  <!-- page header for sets -->
  <xsl:template name="set_header">
    <xsl:param name="display_name"/>

    <xsl:comment>template: status/root.xsl:view_header</xsl:comment>

    <div class="header rounded-bottom gradient-grey shadow">
      <div class="container">
        <div><xsl:attribute name="class">title span-24 last</xsl:attribute>
        <h1 class="no_icon" style="margin-left: 0;"><xsl:value-of select="$display_name"/></h1>
        </div>
      </div>
    </div>

  </xsl:template>

  <!-- app control bar  -->
  <xsl:template name="control_bar_app">
    <xsl:comment>template: status/root.xsl name:control_bar_app</xsl:comment>

    <div class="control_bar app rounded-bottom shadow">
      <div class="control_bar_menu" id="bar_menu">
        <xsl:call-template name="control_bar_menu"/>
      </div>

      <div class="control_bar_base" id="bar_base">&#160;</div>

    </div>
  </xsl:template>

  <!-- view control bar  -->
  <xsl:template name="control_bar_view">
    <xsl:comment>template: status/root.xsl name:control_bar_view</xsl:comment>
    <div class="control_bar view shadow">
      <div class="control_bar_menu" id="bar_menu">
        <xsl:call-template name="control_bar_menu"/>
      </div>

      <div class="control_bar_base" id="bar_base">&#160;</div>

    </div>
  </xsl:template>

  <!-- application menu for control bars -->
  <xsl:template name="control_bar_menu">
    <xsl:comment>template: status/root.xsl name:control_bar_menu</xsl:comment>

    <ul>
      <li>
        <a href="/view/genome/status.html" class="app btn shadow">
          <div class="icon"><img src="/res/img/icons/app_deprecated_search_16.png" width="16" height="16"/></div>
          Deprecated Search
        </a>
      </li>
      <li>
        <a href="/view/genome/search/status.html" class="app btn shadow">
          <div class="icon"><img src="/res/img/icons/app_analysis_search_16.png" width="16" height="16"/></div>
          Analysis Search
        </a>
      </li>
    </ul>
  </xsl:template>

  <!-- basic footer -->
  <xsl:template name="footer">
    <xsl:param name="footer_text"/>

    <xsl:comment>template: status/root.xsl:footer</xsl:comment>

    <div class="footer rounded shadow span-24 last gradient-grey">
      <div class="container">
        <p class="small">version 1.0b <xsl:copy-of select="$footer_text"/></p>
      </div>
    </div>
  </xsl:template>

</xsl:stylesheet>
