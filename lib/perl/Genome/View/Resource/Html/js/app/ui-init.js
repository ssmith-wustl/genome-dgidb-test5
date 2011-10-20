$(document).ready(
    function() {
        $.ajaxSetup({
            cache: true,
            beforeSend: function(xhr) {
                var d = $(document).data('updatedOn').getTime();
                var elapsed = Math.ceil((Date.now() - d) / 1000);
                xhr.setRequestHeader("X-Max-Age", elapsed.toString());
                return true;
            }
        });

        // apply jQueryUI styles to button elements
        $("a.button, input:submit, button").button();

        // draw last updated time

        if (document.cookie.indexOf("cacheon=1") >= 0) {
            $('#updatedOn').text($(document).data('updatedOn').toString()).easydate();

            $('#refreshCache').click(function() {
                var url = location.pathname.substr(5) + location.search;

                $.ajax({
                    url: '/cachetrigger' + url,
                    success: function(data) {
                        location.reload();
                    }
                });

                $(this).parent().parent().find('.cache_time p').replaceWith("<p style='margin-top: 12px;'><strong>Loading...</strong></p>");

                return false;
            });
        } else {
            $('.cache_info').hide();
        }

        // init masonry for view object container
        $('#objects').masonry(
            {
                columnWidth: 320,
                singleMode: true,
                itemSelector: '.span_8_box_masonry'
            }
        );
        $('#objects').masonry(
            {
                columnWidth: 480,
                singleMode: true,
                itemSelector: '.span_12_box_masonry'
            }
        );

        // set up tasks popup window & button
        $('a#view_all_tasks').click(function() {
            var ptitle = this.title;
            var popup = $("#tasks_table");

            popup.dialog({
                title: ptitle,
                width: 750,
                height: 300
            });

            var dWidget = popup.dialog("widget");

            // tweak titlebar styles
            dWidget.find(".ui-dialog-titlebar").removeClass("ui-corner-all").addClass("ui-corner-top");

            return false;
        });



/*
        // set up control bar state & behavior
        $('#bar_menu, #bar_menu ul').hide();

        var barClosed = 1;

        $('#bar_base').mouseenter(function() {
            if (barClosed) {
                $('#bar_menu')
                    .show('fast', function() {
                        barClosed = 0;
                        $('#bar_menu ul').fadeIn('fast');
                    })
                    .mouseleave(function() {
                        var mouseBackOver = 0;
                        $(this).mouseenter(function(){ mouseBackOver = 1; });

                        // wait for a second to see if user hovers over menu again
                        setTimeout(function() {
                            if (!mouseBackOver) {
                            $('#bar_menu ul')
                                .fadeOut('fast', function(){
                                    $(this).parent()
                                        .hide('fast', function() {
                                            barClosed = 1;
                                        })
                                        .unbind();
                                });
                            }
                        }, 1000);
                    });
            }
        });
*/

    }
);
