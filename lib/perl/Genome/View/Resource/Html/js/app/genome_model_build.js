$(document).ready(function() {

    $("#process_tabs").tabs({
        cache: true,
        spinner: '<span style="color: grey;">loading...</span> ',
        ajaxOptions: {
            error: function(xhr, status, index, anchor) {
                $(anchor.hash).html("Sorry, could not load workflow.");
            }
        }
    });

    // rounded corners only on the top of our tab menu, thank you very much!
    $("#process_tabs ul").removeClass("ui-corner-all").addClass("ui-corner-top");

});

function event_popup(eventObject) {

    // assemble event info into a table
    var popup_content = '<table class="boxy_info" cellpadding="0" cellspacing="0" border="0" width="300"><tbody>';
    for (prop in eventObject) {
        if (prop != 'popup_title') {
            popup_content += '<tr><td class="label">' + prop.replace(/_/g," ") + ':</td><td class="value">' + eventObject[prop] + '</td></tr>';
        }
    }

    popup_content += '</tbody></table>';

    // create popup
    var popup = new Boxy(popup_content, {title:eventObject.popup_title, fixed:false});
    popup.center();
}

