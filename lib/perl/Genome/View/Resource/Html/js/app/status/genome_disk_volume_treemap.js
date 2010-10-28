function render_treemap(data, width, height) {

    // console.log("data: " + JSON.stringify(data));

    // group allocation data by owner_class_name
    var ndata = pv.nest(data)
        .key(function(d) { return d.owner_class_name; })
        .key(function(d) { return d.display_name; })
        .rollup(function(d) { return Number(d[0].kilobytes_requested); });

    console.dir(ndata);

    var color = pv.Colors.category19().by(function(d){ return d.owner_class_name; }),
    nodes = pv.dom(ndata).root("allocations").nodes();

    console.dir(nodes);
    // console.log("Nodes: " + nodes.toSource());

    var vis = new pv.Panel()
        .width(width)
        .height(height)
        .fillStyle("lightgrey");

    var treemap = vis.add(pv.Layout.Treemap)
        .nodes(nodes)
        .round(true)
        .mode("squarify");

    treemap.leaf.add(pv.Panel)
        .fillStyle(function(d) { return color(d); })
        .strokeStyle("#fff")
        .lineWidth(1)
        .antialias(false);

    treemap.label.add(pv.Label)
        .visible(
            function(d) {
                // only show label if panel is large enough to contain it
                // and this is a child node
                var showLabel;
                if (d.parentNode && (d.dx > 50 || d.dy > 50)){
                    showLabel = true;
                } else {
                    showLabel = false;
                }

                return showLabel;
            }
        );

    vis.render();


}