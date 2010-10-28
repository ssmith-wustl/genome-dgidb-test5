function render_treemap(data, width, height) {

    var color = pv.Colors.category19().by(function(d){ return d.owner_class_name; }),
    nodes = pv.dom(data).root("allocation").nodes();

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