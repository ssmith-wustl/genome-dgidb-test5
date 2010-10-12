<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template name="genome_model_metric_set" match="object[./types[./isa[@type='Genome::Model::Metric::Set']]]">

    <xsl:call-template name="control_bar_view"/>

    <xsl:call-template name="set_header">
      <xsl:with-param name="display_name" select="'Query Results'" />
    </xsl:call-template>

    <div class="content rounded shadow">
      <div class="container">
        <div class="set_query rounded span-24 last">
          <div class="padding10">
            <strong>Query: </strong> <xsl:value-of select="aspect[@name='rule_display']/value" />
          </div>
        </div>

        <xsl:call-template name="genome_model_metric_set_chart"/>

        <hr class="space" style="height: 10px; margin: 0;"/>

        <div class="span-24 last">
          <table width="100%" cellpadding="0" cellspacing="0" border="0" id="set" class="dataTable">
            <thead>
              <xsl:apply-templates select="aspect[@name='members']/object[1]" mode="set_header" />
            </thead>
            <tbody>
              <xsl:for-each select="aspect[@name='members']">
                <xsl:apply-templates mode="set_row" />
              </xsl:for-each>
            </tbody>
          </table>
        </div>
        <xsl:apply-templates select="aspect[@name='members']/object[1]" mode="set_table_init" />
      </div> <!-- end container -->
    </div> <!-- end content -->

    <xsl:call-template name="footer">
      <xsl:with-param name="footer_text">
        <br/>
      </xsl:with-param>
    </xsl:call-template>

  </xsl:template>

  <xsl:template name="genome_model_metric_set_chart">
    <script type="text/javascript" src="/res/js/pkg/protovis.js"></script>
    <script type="text/javascript">
    </script>


    <script type="text/javascript+protovis">
      <xsl:text disable-output-escaping="yes">
        <![CDATA[


function renderGraph(data) {

    console.log(data.length);

    /* Sizing and scales. */
    var w = 400,
        h = 200,
        x = pv.Scale.linear(0, data.length - 1).range(0, w),
        y = pv.Scale.linear(data, function(d) d.y).range(0, h);

    /* The root panel. */
    var vis = new pv.Panel()
        .width(w)
        .height(h)
        .bottom(100)
        .left(50)
        .right(10)
        .top(5);

    /* X-axis ticks. */
    vis.add(pv.Rule)
        .data(data)
        .left(function(d) x(this.index))
        .strokeStyle("#eee")
        .add(pv.Rule)
        .bottom(-25)
        .height(0)
        .strokeStyle("#000")
        .anchor("bottom").add(pv.Label)
        .textAngle(Math.PI/2)
        .text(function(d) { return d.x } );

    /* Y-axis ticks. */
    vis.add(pv.Rule)
        .data(y.ticks())
        .bottom(y)
        .strokeStyle(function(d) d ? "#eee" : "#000")
        .anchor("left").add(pv.Label)
        .text(y.tickFormat);

    /* The line. */
    vis.add(pv.Line)
        .data(data)
        .left(function(d) x(this.index))
        .bottom(function(d) y(d.y))
        .lineWidth(3);

    vis.canvas('fig')
    vis.render();
}

$(document).ready(function () {

    $.ajax({
        url: location.href.replace('.html','.json'),
        dataType: 'json',
        success: function(data) {

            var chartData = data["members"].filter(function(m) {
                if (m.name == "rbytes") {
                    return true;
                }
            }).map(function(m) {
                return { x: m.build_id, y: m.value };
            });

            renderGraph(chartData);
        }
    });

});
        ]]>
      </xsl:text>
    </script>

  <div id="fig"></div>
  <div id="out"></div>

  </xsl:template>

</xsl:stylesheet>
