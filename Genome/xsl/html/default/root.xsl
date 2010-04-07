<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html"/>
  <xsl:output doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"/>
  <xsl:output doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"/>

  <xsl:strip-space elements="*"/>

  <xsl:template match="/">
    <html>
      <head>
        <style type="text/css">
          <![CDATA[
                   body {
                   padding: 0;
                   margin: 0;
                   background-color:#efefef;
                   font-family: Helvetica, Arial, sans-serif;
                   color: #333;
                   }

div.container {
width: 800px;
margin: 0 auto;
font-size: 13px;
}

div.background {
float: left;
background-color: #FFF;
width: 800px;
}

div.content {
width: 760px;
padding: 15px 20px;
border-bottom: 5px solid #AAA;
}

div.header_object {
background: #CCC;
border-bottom: 5px solid #AAA;
}

div.header_object h1 {
margin: 0;
padding: 0;
line-height: 35px;
font-size: 22px;
padding-left: 15px;
}

span.id {
font-weight: normal;
}

span.display_name {

}

p.exception {
font-weight: bold;
color: #C33;
}

table.aspects {
width:100%;
border-collapse: collapse;
}

table.aspects td {
padding: 6px 5px 6px 5px;
border-bottom: 1px solid #EFEFEF;
}

table.aspects td.name {
text-align: right;
vertical-align: top;
}

table.aspects td.value p {
margin: 0 0 5px 0;
padding: 0;
}

          ]]>
        </style>
      </head>
      <body>
        <div class="container">
          <div class="background">
            <xsl:apply-templates/>
          </div>
        </div>
      </body>
    </html>
  </xsl:template>

</xsl:stylesheet>
