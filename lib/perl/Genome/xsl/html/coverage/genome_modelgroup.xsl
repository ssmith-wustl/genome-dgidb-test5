<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">


  <xsl:template name="genome_modelgroup" match="object[@type='Genome::ModelGroup']">
    <script type="text/javascript" src="/res/js/pkg/protovis.js"></script>
    <script type="text/javascript">
      window.aSummary = [
      <xsl:for-each select="//alignment-summary/model">
        <xsl:sort data-type="text" order="ascending" select="@subject_name"/>
        <xsl:if test="total_bp"> <!-- we may get empty model nodes, which should be discarded -->
          {
          "subject_name": "<xsl:value-of select="@subject_name"/>",
          "id": <xsl:value-of select="@id"/>,
          "total_bp": <xsl:value-of select="total_bp"/>,
          "total_unaligned_bp": <xsl:value-of select="total_unaligned_bp"/>,
          "duplicate_off_target_aligned_bp": <xsl:value-of select="duplicate_off_target_aligned_bp"/>,
          "duplicate_target_aligned_bp": <xsl:value-of select="duplicate_target_aligned_bp"/>,
          "unique_off_target_aligned_bp": <xsl:value-of select="unique_off_target_aligned_bp"/>,
          "unique_target_aligned_bp": <xsl:value-of select="unique_target_aligned_bp"/>,
          }<xsl:if test="position() != last()"><xsl:text>,</xsl:text></xsl:if>
        </xsl:if>
      </xsl:for-each>
      ];
      window.cSummary = {
      <xsl:for-each select="//coverage-summary/model">
        <xsl:sort data-type="text" order="ascending" select="@subject_name"/>
        "<xsl:value-of select="@subject_name"/>": {
        "pc_target_space_covered": {
        <xsl:for-each select="minimum_depth">
          <xsl:sort data-type="number" order="descending" select="@value"/>
          "<xsl:value-of select="@value"/>": <xsl:value-of select="pc_target_space_covered"/><xsl:if test="position() != last()"><xsl:text>,</xsl:text></xsl:if>
        </xsl:for-each>
        },
        "pc_target_space_covered_eighty_pc_breadth": {
        <xsl:for-each select="minimum_depth">
          <xsl:sort data-type="number" order="descending" select="@value"/>
          "<xsl:value-of select="@value"/>": <xsl:value-of select="pc_target_space_covered_eighty_pc_breadth"/><xsl:if test="position() != last()"><xsl:text>,</xsl:text></xsl:if>
        </xsl:for-each>
        }

        }<xsl:if test="position() != last()"><xsl:text>,</xsl:text></xsl:if>
      </xsl:for-each>
      };

    </script>

    <xsl:call-template name="control_bar_view"/>

    <xsl:call-template name="view_header">
      <xsl:with-param name="label_name" select="'Model Group Coverage:'" />
      <xsl:with-param name="display_name" select="@id" />
      <xsl:with-param name="icon" select="'genome_modelgroup_32'" />
    </xsl:call-template>

    <div class="content rounded shadow">
      <div class="container">

        <table border="0" cellpadding="0" cellspacing="0" class="info_table">
          <tr>
            <td class="label">Model Group Name:</td>
            <td class="value"><xsl:value-of select="@name"/></td>
          </tr>
          <tr>
            <td class="label">Models in Group:</td>
            <td class="value"><xsl:value-of select="count(//coverage-summary/model)"/></td>
          </tr>
        </table>

        <div id="charts" style="float: left; width: 920px;">

          <table width="100%" border="0" cellpadding="0" cellspacing="0">
            <tr>
              <td style="vertical-align: top; padding-right: 10px;">
                <h2>coverage</h2>
                <script type="text/javascript+protovis">
                  <xsl:text disable-output-escaping="yes">
                  <![CDATA[
                           /* get chart data into nice arrays */
                           var models = pv.keys(cSummary);
                           var types = pv.keys(cSummary[models[0]]);
                           var depths = pv.keys(cSummary[models[0]].pc_target_space_covered).sort(function(a,b) { b-a });

//convert full % to stacked %
var coverage_data = []; // this will store the stacked version of the coverage data
var coverage_data_full = []; // we'll need this to show the full instead of the stacked % in rollovers

for (var model in cSummary) {
var full_depth_pc = [];
var stacked_depth_pc = [];
var i = 0;
for (var depth in cSummary[model].pc_target_space_covered) {
var stacked_depth; // stores the result of the full to stacked depth conversion
var full_depth;
if (i == 0) {
// this highest depth w/ the lowest coverage, so it will be fully displayed.
stacked_depth = cSummary[model].pc_target_space_covered[depths[i]];
full_depth = stacked_depth;
} else {
// subtract lower depth from this depth
stacked_depth = cSummary[model].pc_target_space_covered[depths[i]] -
cSummary[model].pc_target_space_covered[depths[i-1]];
full_depth = cSummary[model].pc_target_space_covered[depths[i]];
}
stacked_depth_pc.push(round(stacked_depth, 3));
full_depth_pc.push(full_depth);
i++;
}
coverage_data.push(stacked_depth_pc);
coverage_data_full.push(full_depth_pc);
}

// protovis' Stack layout likes the data w/ one array per layer instead of one per column,
// hence we must transpose the conversion results
var coverage_data_t = pv.transpose(coverage_data);

var coverage_w = 340,
coverage_h = 16 * models.length,
coverage_x = pv.Scale.linear(0, 100).range(0, coverage_w-10),
coverage_y = pv.Scale.ordinal(pv.range(models.length)).splitBanded(0, coverage_h, .90),
c = pv.Colors.category20();

var coverage_vis = new pv.Panel()
.width(coverage_w)
.height(coverage_h)
.bottom(0)
.left(175)
.right(10)
.top(100);

var bar = coverage_vis.add(pv.Layout.Stack)
.layers(coverage_data_t)
.orient("left-top")
.x(function() coverage_y(this.index))
.y(coverage_x)
.layer.add(pv.Bar)
.height(coverage_y.range().band)
.fillStyle(function(d) c(this.parent.index))
.title(function() "depth: " + depths[this.parent.index] + "; target space covered: " + coverage_data_full[this.index][this.parent.index] + "%"  );

bar.anchor("right").add(pv.Label)
.visible(function(d) this.parent.index == 0) // only show a label on the first layer
.textStyle("white")
.text(function(d) d.toFixed(1) );

bar.anchor("left").add(pv.Label)
.visible(function() !this.parent.index)
.textMargin(5)
.textAlign("right")
.text(function() models[this.index]);

coverage_vis.add(pv.Rule)
.data(coverage_x.ticks())
.left(coverage_x)
.strokeStyle(function(d) {
var color;
switch (d) {
case 0:
color = "#AAA";
break;
case 80: // highlight the 80% rule
color = "#F00";
break;
default:
color = "rgba(255,255,255,.3)";
break;
}
return color;
})
.add(pv.Rule)
.top(0)
.height(5)
.strokeStyle("rgba(255,255,255,.3)")
.anchor("top").add(pv.Label)
.text(function(d) d.toFixed());

// legend
coverage_vis.add(pv.Panel)
.top(-90)
.left(-170)
.add(pv.Dot)
.data(depths)
.top(function() this.index * 15)
.size(8)
.shape("square")
.strokeStyle(null)
.fillStyle(function(d) c(this.index))
.anchor("right").add(pv.Label)
.text(function(d) "depth " + d );

// x axis label
coverage_vis.add(pv.Label)
.left(130)
.font("bold 14px sans-serif")
.top(-25)
.text("coverage (%)");


coverage_vis.render();

function round(rnum, rlength) {
return Math.round(rnum*Math.pow(10,rlength))/Math.pow(10,rlength);
}
                  ]]>
                </xsl:text>
                </script>
              </td>
              <td style="vertical-align: top;">
                <h2>alignment</h2>
                <script type="text/javascript+protovis">
                  <xsl:text disable-output-escaping="yes">
                  <![CDATA[

var metrics = [
"unique_target_aligned_bp",
"duplicate_target_aligned_bp",
"unique_off_target_aligned_bp",
"duplicate_off_target_aligned_bp",
"total_unaligned_bp"
];

var metrics_short = [
"unique on target",
"duplicate on target",
"unique off target",
"duplicate off target",
"unaligned"
];

// create column arrays
var summary_data = [];
for (var subject in aSummary) {
var summary_col = [];
for (var i in metrics) {
summary_col.push(aSummary[subject][metrics[i]]);
}
summary_data.push(summary_col);
}

// determine max to calculate the width of the chart
var max = pv.max(aSummary, function(d) d.total_bp);

// protovis' Stack layout likes the data w/ one array per layer instead of one per column,
// hence we must transpose the conversion results
var summary_data_t = pv.transpose(summary_data);

var alignment_w = 395,
alignment_h = 16 * aSummary.length,
alignment_x = pv.Scale.linear(0, max).range(0, alignment_w-10),
alignment_y = pv.Scale.ordinal(pv.range(aSummary.length)).splitBanded(0, alignment_h, .90),
c = pv.Colors.category20();

var alignment_vis = new pv.Panel()
.width(alignment_w)
.height(alignment_h)
.bottom(0)
.left(0)
.right(10)
.top(100);

var bar = alignment_vis.add(pv.Layout.Stack)
.layers(summary_data_t)
.orient("left-top")
.x(function() alignment_y(this.index))
.y(alignment_x)
.layer.add(pv.Bar)
.height(alignment_y.range().band)
.fillStyle(function(d) c(this.parent.index))
.title(function(d) "subject: " + aSummary[this.index].subject_name + "; " + metrics_short[this.parent.index] + ": " + addCommas(d) );

bar.anchor("right").add(pv.Label)
.visible(function() this.parent.index == 0 ) // only show a label when the bar is wide enough
.textStyle("white")
.text(function(d) round(d/1000000000,2) );

// bar.anchor("left").add(pv.Label)
//     .visible(function() !this.parent.index)
//     .textMargin(5)
//     .textAlign("right")
//     .text(function() aSummary[this.index].subject_name );

// add x axis rules
alignment_vis.add(pv.Rule)
.data(alignment_x.ticks(5))
.left(alignment_x)
.strokeStyle(function(d) (d == 0 || d == max) ? "#AAA" : "rgba(255,255,255,.3)")
.add(pv.Rule)
.top(0)
.height(5)
.strokeStyle("rgba(255,255,255,.3)")
.anchor("top").add(pv.Label)
.text(function(d) d == 0 ? "" : d/1000000000);

// add target rule
alignment_vis.add(pv.Rule)
.data([6000000000])
.left(alignment_x)
.strokeStyle("#F00")
.add(pv.Rule)
.top(-10)
.height(15)
.strokeStyle("#F00")
.anchor("top").add(pv.Label)
.text(function(d) d/1000000000);

// legend

alignment_vis.add(pv.Panel)
.top(-90)
.left(5)
.add(pv.Dot)
.data(metrics_short)
.top(function() this.index * 15)
.size(8)
.shape("square")
.strokeStyle(null)
.fillStyle(function(d) c(this.index))
.anchor("right").add(pv.Label);

// x axis label
alignment_vis.add(pv.Label)
.left(130)
.font("bold 14px sans-serif")
.top(-25)
.text("sequence (Gb)");

alignment_vis.render();

function addCommas(nStr) {
nStr += '';
var x = nStr.split('.');
var x1 = x[0];
var x2 = x.length > 1 ? '.' + x[1] : '';
var rgx = /(\d+)(\d{3})/;
while (rgx.test(x1)) {
x1 = x1.replace(rgx, '$1' + ',' + '$2');
}
return x1 + x2;
}

function round(rnum, rlength) {
return Math.round(rnum*Math.pow(10,rlength))/Math.pow(10,rlength);
}
                  ]]>
                  </xsl:text>
                </script>
              </td>
            </tr>
          </table>
        </div>

        <h2>alignment summary</h2>
        <table class="list" width="100%" cellspacing="0" cellpadding="0" border="0">
          <thead>
            <tr>
              <th>subject</th>
              <th>unique on-target</th>
              <th>duplicate on-target</th>
              <th>unique off-target</th>
              <th>duplicate off-target</th>
              <th>unaligned</th>
            </tr>
          </thead>
          <tbody>
            <xsl:for-each select="alignment-summary/model">
              <xsl:sort select="@subject_name" order="ascending"/>
              <tr>
                <td>
                  <xsl:value-of select="@subject_name"/>
                </td>
                <td>
                  <xsl:value-of select="format-number(unique_target_aligned_bp, '###,###')"/>
                </td>
                <td>
                  <xsl:value-of select="format-number(duplicate_target_aligned_bp, '###,###')"/>
                </td>
                <td>
                  <xsl:value-of select="format-number(unique_off_target_aligned_bp, '###,###')"/>
                </td>
                <td>
                  <xsl:value-of select="format-number(duplicate_off_target_aligned_bp, '###,###')"/>
                </td>
                <td>
                  <xsl:value-of select="format-number(total_unaligned_bp, '###,###')"/>
                </td>
              </tr>
            </xsl:for-each>
          </tbody>
        </table>
        <h2>depth summary</h2>
        <table class="list" width="100%" cellspacing="0" cellpadding="0" border="0">
          <thead>
            <tr>
              <th>subject</th>
              <xsl:for-each select="coverage-summary/minimum_depth_header">
                <xsl:sort select="@value" data-type="number" order="descending"/>
                <th>
                  <xsl:value-of select="@value"/>X
                </th>
              </xsl:for-each>
            </tr>
          </thead>
          <tbody>
            <xsl:for-each select="coverage-summary/model">
              <xsl:sort select="@subject_name" order="ascending"/>
              <tr>
                <td>
                  <xsl:value-of select="@subject_name"/>
                </td>
                <xsl:for-each select="minimum_depth">
                  <xsl:sort select="@value" data-type="number" order="descending"/>
                  <td>
                    <xsl:value-of select="pc_target_space_covered"/>%
                  </td>
                </xsl:for-each>
              </tr>
            </xsl:for-each>
          </tbody>
        </table>
        <h2>breadth >=80% summary</h2>
        <table class="list" width="100%" cellspacing="0" cellpadding="0" border="0">
          <thead>
            <tr>
              <th>subject</th>
              <xsl:for-each select="coverage-summary/minimum_depth_header">
                <xsl:sort select="@value" data-type="number" order="descending"/>
                <th>
                  <xsl:value-of select="@value"/>X
                </th>
              </xsl:for-each>
            </tr>
          </thead>
          <tbody>
            <xsl:for-each select="coverage-summary/model">
              <xsl:sort select="@subject_name" order="ascending"/>
              <tr>
                <td>
                  <xsl:value-of select="@subject_name"/>
                </td>
                <xsl:for-each select="minimum_depth">
                  <xsl:sort select="@value" data-type="number" order="descending"/>
                  <td>
                    <xsl:value-of select="pc_target_space_covered_eighty_pc_breadth"/>%
                  </td>
                </xsl:for-each>
              </tr>
            </xsl:for-each>
          </tbody>
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
