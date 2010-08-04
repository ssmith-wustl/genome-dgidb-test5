$(document).ready(
    function() {
        // apply jQueryUI styles to button elements
        $("a.button, input:submit, button").button();
        
        // init masonry for view object container
        $('#objects').masonry(
            {
                columnWidth: 320,
                singleMode: true,
                itemSelector: '.span_8_box_masonry'
            }
        );
        
    }
);
