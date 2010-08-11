$(document).ready(function() {

    $("#process_tabs").tabs({
        ajaxOptions: {
            spinner: '<img src="/res/img/spinner.gif" width="16" height="16" alt="spinner"/>',
            error: function(xhr, status, index, anchor) {
                $(anchor.hash).html("Sorry, could not load workflow.");
            }
        }
    });

    // $('#show_events').click(function() {
    //     $('#workflowview').hide();
    //     $('#eventview').show();
    //     return false;
    // });

    // $('#show_workflow').click(function() {
    //     $('#eventview').hide();
    //     if ($('#workflowview').length == 0) {
    //         $('.viewport').append('<div id="workflowview"></div>');
            
    //         $('#workflowview').load('/view/workflow/operation/instance/statuspopup.html?id=' + window.page_data.workflow["id"]);
    //     }
        
    //     $('#workflowview').show();
    //         return false;
    //  });

    //  if (window.page_data.stages["count"] == 0) {
    //      $('#show_workflow').click();
    //  }
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

