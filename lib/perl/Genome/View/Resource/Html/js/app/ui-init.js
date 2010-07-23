$(document).ready(function() {
    $("a.button, input:submit, button").button();

    $('#objects').masonry({
        columnWidth: 320,
        singleMode: true,
        itemSelector: '.span_8_box_masonry'
    });
});
