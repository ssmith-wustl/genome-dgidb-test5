prepareDataTables = (data) ->
    columns = data.aoColumns
    for col in columns
        val = col.mDataProp
        $("#table-header").append($("<th>#{val}</th>"))
    $("#task-list").dataTable(data)

$ ()->
    $.ajax
        url: '/view/genome/task/set/data-table.json'
        dataType: 'json'
        success: (data) ->
            prepareDataTables(data) 
