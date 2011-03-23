
$(document).ready(function() {

    $('#searchBox').focus();

    $('#searchForm').submit(function() { 

        if ($('#searchBox').val() == '') {
            return false;
        }

        return true;
    } );

});


