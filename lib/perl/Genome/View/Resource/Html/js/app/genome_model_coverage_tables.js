// INCLUDED FROM:
// xsl/html/coverage/genome_model.xsl

$(document).ready(function() {
    $('#alignment-lister').dataTable( {
                     "sDom": 'T<"clear">lfrtip',
                         "oTableTools": {
                         "sSwfPath": "/res/js/pkg/TableTools/media/swf/copy_cvs_xls_pdf.swf"
                     },
                         "sPaginationType": "full_numbers",
                         "aoColumns": [  null,
                                         {"sType": "formatted-num"},
                                         {"sType": "formatted-num"},
                                         {"sType": "formatted-num"},
                                         {"sType": "formatted-num"},
                                         {"sType": "formatted-num"},
                                      ]
                         });
    $('#coverage-depth-lister,#coverage-summary-lister').dataTable( {
                     "sDom": 'T<"clear">lfrtip',
                         "oTableTools": {
                         "sSwfPath": "/res/js/pkg/TableTools/media/swf/copy_cvs_xls_pdf.swf"
                     },
                         "sPaginationType": "full_numbers",
                         "aoColumns": [  null,
                                         {"sType": "percent"},
                                         {"sType": "percent"},
                                         {"sType": "percent"},
                                         {"sType": "percent"},
                                         {"sType": "percent"},
                                      ]
                     });
    $('#enrichment-factor-lister').dataTable( {
                     "sDom": 'T<"clear">lfrtip',
                         "oTableTools": {
                         "sSwfPath": "/res/js/pkg/TableTools/media/swf/copy_cvs_xls_pdf.swf"
                     },
                         "sPaginationType": "full_numbers",
                         "aoColumns": [  null,
                                         {"sType": "formatted-num"},
                                         {"sType": "formatted-num"},
                                         {"sType": "formatted-num"},
                                      ]
                     });
});
