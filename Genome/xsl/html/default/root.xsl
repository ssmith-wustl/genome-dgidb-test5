<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:strip-space elements="*"/>

  <xsl:template match="/">
    <html>
      <head>
        <style type="text/css">
          <![CDATA[
body {
  background-color:#dddddd;
  width:800px;
}
tr:nth-child(odd) {
  background-color:#eeeeee;
}
tr:nth-child(even) {
  background-color:#ffffff;
}
.object {
  width:inherit;
}
.identity {
  height: 2.5em;
}
.identity .representation {
  float:right;
  font-size:smaller;
  border-width:1px;
  border-style:dotted;
  height:2.5em; 
}
.identity .display_name {
  float:left;
}
.representation .id {
  text-align:center;
}
.representation .type {
  text-align:center; 
}
TABLE.aspects {
  width:100%;
}
.aspects tr td:first-child {
  vertical-align:top;
}
          ]]>
        </style>
      </head>
      <body>
        <xsl:apply-templates/>
      </body>
    </html>
  </xsl:template>

</xsl:stylesheet>
