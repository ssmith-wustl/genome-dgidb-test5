

$(document).ready(function() {
   
    oTable = $('#samples').dataTable({
        "bProcessing": false,
        "sAjaxSource": "/view/genome/sample/set/detail.json?name%20like=%test_sample%",
        "fnServerData" : function( sSource, aoData, fnCallback ) {
            /* Add some data to send to the source, and send as 'POST' */
            alert("calling ajax");
            $.ajax( {
                "dataType": 'json', 
                "type": "GET", 
                "url": sSource, 
                "data": aoData, 
                "success": function(data, textStatus, jqXHR) {
                    alert("hi");                    
                    fnCallback(data, textStatus, jqXHR);
                }
           }); 
    }
   });

});



