(function() {
  var prepareDataTables;
  prepareDataTables = function(data) {
    var col, columns, val, _i, _len;
    columns = data.aoColumns;
    for (_i = 0, _len = columns.length; _i < _len; _i++) {
      col = columns[_i];
      val = col.mDataProp;
      $("#table-header").append($("<th>" + val + "</th>"));
    }
    return $("#task-list").dataTable(data);
  };
  $(function() {
    return $.ajax({
      url: '/view/genome/task/set/data-table.json',
      dataType: 'json',
      success: function(data) {
        return prepareDataTables(data);
      }
    });
  });
}).call(this);
