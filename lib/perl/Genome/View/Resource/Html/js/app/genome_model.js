$(document).ready(function() {

    var flagstat = $("div#flagstat_table").dialog({
        title: "Flagstat Report",
        width: 500,
        height: 450,
        autoOpen: false
    });

    // tweak titlebar styles
    var dWidget = flagstat.dialog("widget");
    dWidget.find(".ui-dialog-titlebar").removeClass("ui-corner-all").addClass("ui-corner-top");

    $('a#flagstat_button').click(
        function() {
            $('div#flagstat_table').dialog('open');
            return false;
        }
    );

});