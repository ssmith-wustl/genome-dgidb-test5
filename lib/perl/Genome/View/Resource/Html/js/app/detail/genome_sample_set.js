

   
$(document).ready(function() {

    var ajaxData;
    var source = "/view/genome/sample/set/detail.json?" + window.location.search.substring(1);

    $(document).data('updatedOn', new Date(1320090254000));

    $.ajax({
        "dataType": 'json',
        "type": "GET",
        "url": source,
        "error" : function (jqXHR, textStatus, errorThrown) {
            alert("failed to get data for samples table");
        },
        "success": function (data, textStatus, jqXHR) {
            var columns = data.aoColumns;
            var header_row = $('#table-header');
            for (i=0;i<columns.length;i++) {
                header_row.append($('<th>' + columns[i].mDataProp + '</th>'));
            }
            data.bJQueryUI = true;
            $('#samples').dataTable(data);
        }
    });

});




