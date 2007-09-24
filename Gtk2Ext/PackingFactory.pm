package Gtk2Ext::PackingFactory;

use strict;
use warnings;

use base 'Finfo::Singleton';

use Data::Dumper;
use Gtk2::Pango; 
use Gtk2::SimpleList;
use Gtk2::Ex::Simple::Menu;
use Gtk2Ext::Info;
use Gtk2Ext::Utils;

my %size :name(size:o) :type(int_between) :options([qw/ 30 100 /]) :default('100');

sub title
{
    return Gtk2Ext::Info->instance->default_title;
}

sub utils
{
    return Gtk2Ext::Utils->instance;
}

# Sizing
sub determine_and_set_size_for_widget : PRIVATE
{
    my ($self, $widget, $p) = @_;

    Finfo::Validate->validate
    (
        attr => 'widget to adjust and set size',
        value => $widget,
        type => 'object',
        err_cb => $self,
    );

    my $h = ( exists $p->{h} )
    ? delete $p->{h}
    : 400;
    
    my $v = ( exists $p->{v} )
    ? delete $p->{v}
    : 400;

    return ( delete $p->{no_size_red} )
    ? $widget->set_size_request($h, $v)
    : $widget->set_size_request( $self->adjust_sizes($h, $v) );
}

sub adjust_sizes : PRIVATE
{
    my ($self, $h, $v) = @_;

    my $pct = $self->size;

    my $new_h = $h * $pct / 100;

    my $new_v = $v * $pct / 100;

    return ($new_h, $new_v);
}

# Window
sub create_window
{
    my ($self, %p) = @_;
    
    my $win = Gtk2::Window->new('toplevel');
    $win->set_title( delete $p{title} || $self->title);
    
    my $pos = 'center';
    if ( exists $p{position} )
    {
        $pos = delete $p{position};

        Finfo::Validate->validate
        (
            attr => 'window_position',
            value => $pos,
            type => 'in_list',
            options => [ $self->info->window_positions ],
            err_cb => $self,
        );
    }
    $win->set_position($pos);

    $win->set_border_width( delete $p{border_w} || 0 );
    $win->set_reallocate_redraws( delete $p{redraws} || 0 );
    
    $self->determine_and_set_size_for_widget($win, \%p);

    my $events = delete $p{events};
    unless ( exists $events->{delete_event} )
    {
        $events->{delete_event} = sub{ Gtk2->main_quit };
    }

     $self->utils->add_events_to_widget($win, $events);

    $self->utils->add_color_to_widget($win, delete $p{color}) if exists $p{color};

    $self->fatal_msg("Unknown params sent to create_window:" . join(', ', keys %p)) if %p;

    $win->show;
    
    return $win;
}

sub create_window_with_menu
{
    my ($self, %p) = @_;
    
    my $title = delete $p{title} || $self->title;
    my $menu;

    my $win = Gtk2::Window->new('toplevel');
    $win->set_title($title);
    $self->determine_and_set_size_for_widget($win, \%p);
    
    # this should work, but doesn't:
    $win->add_accel_group( $menu->{accel_group} ) if defined $menu;
    
    $win->signal_connect("delete_event", sub{ $self->utils->gtk2_exit });
    $win->show;

    return $win;
}

# Dialog
sub create_dialog
{
    my ($self, %p) = @_;

    my @button_params = ( exists $p{buttons} )
    ? Gtk2Ext::Info->instance->dialog_button_params_for_buttons
    (
        $p{buttons}
    )
    : Gtk2Ext::Info->instance->default_dialog_button_params;

    my $d = Gtk2::Dialog->new
    (
        $p{title} || $self->title,
        $p{parent} || undef,
        $p{flags} || [qw/ modal /],
        @button_params,
    );
    $self->determine_and_set_size_for_widget($d, \%p);
    $p{events}->{'delete-event'} = sub{ return };
    $self->utils->add_events_to_widget($d, $p{events}) if $p{events};

    $d->action_area->set_layout_default( $p{layout} || 'end');
    $d->action_area->set_spacing_default( $p{spacing} || 20 );

    return $d;
}

# Menu
sub create_menu
{
    my ($self, %p) = @_;

    my $menu_tree = delete $p{menu_tree} || delete $p{items};

    $self->display_error("No menu items")
        and return unless defined $menu_tree and @$menu_tree;

    my $menu = Gtk2::Ex::Simple::Menu->new(menu_tree => $menu_tree);
    $menu->{widget}->show;
    
    return $menu;
}

sub add_menu
{   
    my ($self, %p) = @_;

    $p{child} = $self->create_menu(%p)->{widget};

    return $self->add_or_pack_child(%p);
}

# SW
sub create_sw
{
    my ($self, %p) = @_;

    my $h = delete $p{h};
    my $v = delete $p{v};

    my $sw = Gtk2::ScrolledWindow->new();
    $sw->set_size_request($h, $v) if defined $h and defined $v;
    $sw->set_policy( ( exists $p{policy} ) ? @{ $p{policy} } : (qw/ automatic automatic /) );
    $sw->set_shadow_type( $p{shadow} || 'etched-out' );
    $sw->set_border_width( $p{bw} || 0 );
    $sw->show;

    return $sw;
}

sub add_sw
{
    my ($self, %p) = @_;

    $p{child} = $self->create_sw(%p);

    return $self->add_or_pack_child(%p);
}

# Pane
sub create_pane
{
    my ($self, %p) = @_;

    Finfo::Validate->validate
    (
        attr => 'type of pane',
        value => $p{type},
        type => 'in_list',
        options => [qw/ V v H h /],
        err_cb => $self,
    );

    my $pkg = 'Gtk2::' .  uc $p{type} . 'Paned';

    my $pane = $pkg->new();
    $pane->show;

    return $pane;
}

sub add_pane
{
    my ($self, %p) = @_;

    $p{child} = $self->create_pane(%p);

    return $self->add_or_pack_child(%p);
}

# Frame
sub create_frame
{
    my ($self, %p) = @_;

    my $frame = Gtk2::Frame->new( $p{text} || '' );
    $frame->set_shadow_type( $p{shadow} || 'etched_in' );
    $frame->show;

    return $frame;
}

sub add_frame
{
    my ($self, %p) = @_;

    $p{child} = $self->create_frame(%p);

    return $self->add_or_pack_child(%p);
}

# Boxes
sub create_box
{
    my ($self, %p) = @_;

    $p{type} = 'v' unless exists $p{type};

    Finfo::Validate->validate
    (
        attr => 'type of box',
        value => $p{type},
        type => 'in_list',
        options => [qw/ V v H h /],
        err_cb => $self,
    );

    my $pkg = 'Gtk2::' . uc($p{type}) . 'Box';
    my $box = $pkg->new( $p{homogen} || 0, $p{spacing} || 0);
    $box->set_border_width( $p{border} || 0 );
    $box->show;

    return $box;
}

sub add_box
{
    my ($self, %p) = @_;
    
    $p{child} = $self->create_box(%p);
    
    return $self->add_or_pack_child(%p);
}

sub create_bbox
{
    my ($self, %p) = @_;

    $p{type} = 'v' unless exists $p{type};
    
    Finfo::Validate->validate
    (
        attr => 'type of bbox',
        value => $p{type},
        type => 'in_list',
        options => [qw/ V v H h /],
        err_cb => $self,
    );

    my $pkg = 'Gtk2::' . uc($p{type}) . 'ButtonBox';
    my $box = $pkg->new();
    $box->set_layout_default( $p{layout} || 'start' );
    $box->set_spacing_default( $p{spacing} || 10 );
    
    $box->show;

    return $box;
}

sub add_bbox
{
    my ($self, %p) = @_;
    
    $p{child} = $self->create_bbox(%p);
    
    return $self->add_or_pack_child(%p);
}

# Table
sub create_table
{
    my ($self, %p) = @_;

    Finfo::Validate->validate
    (
        attr => 'columns for table',
        value => $p{col},
        type => 'positive_integer',
        err_cb => $self,
    );

    Finfo::Validate->validate
    (
        attr => 'rows for table',
        value => $p{row},
        type => 'positive_integer',
        err_cb => $self,
    );

    my $table = Gtk2::Table->new($p{row}, $p{col}, $p{homogen} || 1);
    $table->set_col_spacings(2);
    $table->set_row_spacings(2);
    $table->show;

    return $table;
}

sub add_table
{
    my ($self, %p) = @_;

    $p{child} = $self->create_table(%p);

    return $self->add_or_pack_child(%p);
}

sub add_to_table
{
    my ($self, %p) = @_;

    my $table = delete $p{table};
    my $child = delete $p{child};
    my $left = delete $p{left};
    my $right =delete $p{right};
    my $top = delete $p{top};
    my $bot = delete $p{bot};
    my $xop = delete $p{xop};
    my $yop = delete $p{yop};
    my $xpad = delete $p{xpad};
    my $ypad = delete $p{ypad};

    if (defined $xop and defined $yop and defined $xpad and defined $ypad)
    {
        $table->attach($child, $left, $right, $top, $bot, $xop, $yop, $xpad, $ypad);
    }
    else
    {
        $table->attach_defaults($child, $left, $right, $top, $bot);
    }

    return $child;
}

# Notebook
sub create_nb
{
    my ($self, %p) = @_;

    my $tab_pos = delete $p{tab_pos} || 'top';
    my $scroll = delete $p{scroll} || 1;
    my $popup = delete $p{popup} || 0;

    my $nb = Gtk2::Notebook->new();
    $nb->set_tab_pos($tab_pos);
    $nb->set_scrollable($scroll);
    $nb->popup_enable;# if $popup;
    $nb->show;

    return $nb;
}

sub add_nb
{
    my ($self, %p) = @_;

    $p{child} = $self->create_nb(%p);

    return $self->add_or_pack_child(%p);
}

sub add_page_to_nb
{
    my ($self, %p) = @_;

    Finfo::Validate->validate
    (
        attr => 'notbook to add child to',
        value => $p{nb},
        type => 'object',
        err_cb => $self,
    );
    
    Finfo::Validate->validate
    (
        attr => 'child to add to notbook',
        value => $p{child},
        type => 'object',
        err_cb => $self,
    );

    my $label = $self->create_label(%p);

    $p{nb}->append_page($p{child}, $label);
    
    return $label;
}

sub insert_page_in_nb
{
    my ($self, %p) = @_;

    my $label = $self->create_label(%p);
    $label->show;
    
    $p{nb}->insert_page($p{child}, $label, $p{page_num} || 0);
    
    $p{nb}->set_current_page($p{page_num} || 0);
    
    return $label;
}

# Text
sub create_basic_text
{
    my ($self, %p) = @_;

    my $text = delete $p{text};
    my $edit = (exists $p{edit})
    ? delete $p{edit}
    : 1;
    my $font = delete $p{font};
    my $events = delete $p{events};
    
    my $buffer = Gtk2::TextBuffer->new();
    $self->set_text_in_basic_text($buffer, $text, $font) if defined $text;
    $self->utils->add_events_to_widget($buffer, $events) if $events;

    my $tview = Gtk2::TextView->new_with_buffer($buffer);
    $tview->set_editable($edit);
    $tview->set_cursor_visible($edit);
    $tview->set_size_request($p{h}, $p{v}) if $p{h} and $p{v};
    $tview->show;

    return ($buffer, $tview);
}

sub add_basic_text
{
    my ($self, %p) = @_;

    my ($buffer, $tview) = $self->create_basic_text(%p);

    $p{child} = $tview;

    $self->add_or_pack_child(%p);

    return $buffer;
}

sub get_text_from_basic_text
{
    my ($self, $buffer) = @_;

    return $buffer->get_text
    (
        $buffer->get_start_iter,
        $buffer->get_end_iter,
        1
    );
}

sub set_text_in_basic_text
{   
    my ($self, $buffer, $text, $font) = @_;
    
    $buffer->delete($buffer->get_start_iter, $buffer->get_end_iter);

    $font = 'cour_12' unless defined $font;
    unless ( $buffer->get_tag_table->lookup($font) )
    {
        my $tag = $self->get_tag_for_font($font);
        $tag = $self->get_tag_for_font('cour_12') unless defined $tag;
        $buffer->create_tag($font, %$tag);
    }

    return $buffer->insert_with_tags_by_name($buffer->get_start_iter, $text, $font);
}

# Fonts
sub get_tag_for_font
{
    my ($self, $font) = @_;

    return unless defined $font;

    my %tags = 
    (
        cour_10 => { font => 'Courier', size => 10 * PANGO_SCALE },
        cour_12 => { font => 'Courier', size => 12 * PANGO_SCALE },
        cour_14 => { font => 'Courier', size => 14 * PANGO_SCALE },
        cour_16 => { font => 'Courier', size => 16 * PANGO_SCALE },
        italic => { style => 'italic' },
    );

    return unless exists $tags{$font};

    return $tags{$font};
}

# Entry
sub create_entry
{
    my ($self, %p) = @_;

    my $text = delete $p{text} || '';
    my $edit = ( exists $p{edit} )
    ? delete $p{edit}
    : 1;
    my $events = delete $p{events};
    
    my $entry = Gtk2::Entry->new();
    $entry->set_editable($edit);
    if ( my $h = delete $p{h} and my $v = delete $p{v} )
    {
        $entry->set_size_request( $h, $v);
    }
    $entry->set_text($text);
    $self->utils->add_events_to_widget($entry, $events) if $events;
    $entry->show;

    return $entry;
}

sub add_entry
{
    my ($self, %p) = @_;

    $p{child} = $self->create_entry(%p);

    return $self->add_or_pack_child(%p);
}

# Label
sub create_label
{
    my ($self, %p) = @_;

    my $label = Gtk2::Label->new($p{text} || '');
    $label->set_alignment($p{h_al}, $p{v_al}) if exists $p{h_al} and exists $p{v_al};
    $label->set_markup( $p{markup} ) if $p{markup};
    $label->show;

    return $label;
}

sub add_label
{
    my ($self, %p) = @_;

    $p{child} = $self->create_label(%p);

    return $self->add_or_pack_child(%p);
}

# Combo
sub create_combo
{
    my ($self, %p) = @_;

    Finfo::Validate->validate
    (
        attr => 'popdowns for combo',
        value => $p{popdowns},
        type => 'non_empty_aryref',
        err_cb => $self,
    );

    my $combo = Gtk2::Combo->new();
    $combo->set_size_request($p{h}, $p{v}) if $p{h} and $p{v};
    $combo->set_popdown_strings( @{ $p{popdowns} } );
    $combo->entry->set_editable($p{edit} || 0);
    $combo->set_use_arrows($p{arrows} || 1);
    $combo->list->select_item(0);
    $self->utils->add_events_to_widget($combo->entry, $p{events}) if $p{events};
    $combo->show;

    return $combo;
}

sub add_combo
{
    my ($self, %p) = @_;

    $p{child} = $self->create_combo(%p);

    return $self->add_or_pack_child(%p);
}

# Separator
sub create_sep
{
    my ($self, %p) = @_;

    my $type = uc delete $p{type} || 'V';

    Finfo::Validate->validate
    (
        attr => 'type of separator',
        value => $type,
        type => 'in_list',
        options => [qw/ V H /],
        err_cb => $self,
    );

    my $pkg = 'Gtk2::' . $type . 'Separator';
    
    my $sep = $pkg->new();
    $sep->show;

    return $sep;
}

sub add_sep
{
    my ($self, %p) = @_;

    my ($parent_type) = ref($p{parent}) =~ /^Gtk2::([HV])(Button)?Box/;
    my $type = ( $parent_type eq 'V' )
    ? 'H'
    : 'V';

    $p{child} = $self->create_sep(type => $type);

    return $self->add_or_pack_child(%p);
}

# Buttons
sub create_button
{
    my ($self, %p) = @_;

    my $button = ( exists $p{stock} )
    ? Gtk2::Button->new_from_stock($p{stock})
    : Gtk2::Button->new_with_label($p{text});

    $self->utils->add_events_to_widget($button, $p{events}) if $p{events};
    $self->utils->add_color_to_widget($button, $p{color}) if $p{color};
    $button->show;
    
    return $button;
}

sub add_button
{
    my ($self, %p) = @_;

    $p{child} = $self->create_button(%p);

    return $self->add_or_pack_child(%p);
}

sub create_check_button
{
    my ($self, %p) = @_;

    my $button = Gtk2::CheckButton->new_with_label($p{text} || '');
    $button->set_active(1) if $p{active};
    $self->utils->add_events_to_widget($button, $p{events}) if $p{events};
    $self->utils->add_color_to_widget($button, $p{color}) if $p{color};
    $button->show;
    
    return $button;
}

sub add_check_button
{
    my ($self, %p) = @_;

    $p{child} = $self->create_check_button(%p);

    return $self->add_or_pack_child(%p);
}

sub create_radio_button
{
    my ($self, %p) = @_;

    my $button = Gtk2::RadioButton->new_with_label($p{group}, $p{text});
    $self->utils->add_events_to_widget($button, $p{events}) if $p{events};
    $self->utils->add_color_to_widget($button, $p{color}) if $p{color};
    $button->show;

    return $button;
}

sub add_radio_button
{
    my ($self, %p) = @_;

    $p{child} = $self->create_radio_button(%p);

    return $self->add_or_pack_child(%p);
}

# Crates
sub pack_ecrate
{
    my ($self, %p) = @_;

    Finfo::Validate->validate
    (
        attr => 'ecrate to add',
        value => $p{ecrate},
        type => 'inherits_from',
        options => [qw/ Gtk2Ext::EntryCrate /],
        err_cb => $self,
    );
    
    $p{child} = $p{ecrate}->box;

    return $self->add_or_pack_child(%p);
}

sub pack_cb_crate
{
    my ($self, %p) = @_;

    $p{child} = $p{cb_crate}->bbox;

    return $self->add_or_pack_child(%p);
}

sub pack_rb_crate
{
    my ($self, %p) = @_;

    $p{child} = $p{rb_crate}->bbox;

    return $self->add_or_pack_child(%p);
}

# Adding and Packing
sub add_or_pack_child
{
    my ($self, %p) = @_;

    $self->fatal_msg("No parent to pack into")
        and return unless defined $p{parent};
    $self->fatal_msg("No child to pack")
        and return unless defined $p{child};

    unless ( exists $p{'pack'} and grep { $p{'pack'} eq $_ } (qw/ start end /) )
    {
        $p{'pack'} = 'start' 
    }

    if ( $p{parent}->isa('Gtk2::Window') or $p{parent}->isa('Gtk2::Frame') )
    {
        return $self->_add_child(%p);
    }
    elsif ($p{parent}->isa('Gtk2::ScrolledWindow'))
    {
        return $self->_add_child_to_sw(%p);
    }
    elsif ($p{parent}->isa('Gtk2::Paned'))
    {
        return $self->_add_child_to_pane(%p);
    }
    else
    {
        return $self->_pack_child(%p);
    }
}

sub _add_child : PRIVATE
{
    my ($self, %p) = @_;

    $p{parent}->add( $p{child} );

    return $p{child};
}

sub _pack_child : PRIVATE
{
    my ($self, %p) = @_;

    my $pack_method = 'pack_' . $p{'pack'};
    
    $p{parent}->$pack_method
    (
        $p{child}, 
        ( exists $p{expand} ) ? $p{expand} : 1, 
        ( exists $p{fill} ) ? $p{fill} : 1, 
        ( exists $p{pad} ) ? $p{pad} : 10, 
    );

    $p{parent}->reorder_child( $p{child}, $p{reorder} ) if exists $p{reorder};
        
    return $p{child};
}

sub _add_child_to_sw : PRIVATE
{
    my ($self, %p) = @_;

    if ( grep { $p{child}->isa("Gtk2::$_") } (qw/ HBox VBox Notebook VButtonBox HButtonBox Table /) )
    {
        $p{parent}->add_with_viewport( $p{child} );
    }
    else
    {
        $p{parent}->add( $p{child} );
    }

    return $p{child};
}

sub _add_child_to_pane : PRIVATE
{
    my ($self, %p) = @_;

    my $method = 'add' . $p{side};
    
    $p{parent}->$method( $p{child} );

    return $p{child};
}

sub add_page_header
{
    my ($self, %p) = @_;
    
    my $parent = delete $p{parent}; # or error
    my $expand = delete $p{expand} || 0;
    my $fill = delete $p{fill} || 1;
    my $pad = delete $p{pad} || 10;
    my $text = delete $p{text};
    
    my $header = $self->page_header($text);

    $parent->pack_start($header, $expand, $fill, $pad); #param for pack start/end?

    return $header;
}

sub page_header
{
    my ($self, $text) = @_;

    my $vbox = Gtk2::VBox->new(0, 0);
    $vbox->show;
    
    $self->add_sep
    (
        parent => $vbox,
        type => 'h',
    );
    
    my $hbox = $self->add_box
    (
        parent => $vbox,
        type => 'h',
    );
    
    $self->add_sep
    (
        parent => $hbox,
        type => 'v',
    );

    my $frame = $self->create_frame();
    
    my $buffer = Gtk2::TextBuffer->new();
    $buffer->create_tag('big', size => 20 * PANGO_SCALE);
    $buffer->create_tag('fg', foreground => 'Blue');
    $buffer->create_tag('italics', style => 'italic');

    my $iter = $buffer->get_start_iter;
    $buffer->insert_with_tags_by_name ($iter, $text, 'big', 'fg', 'italics');

    my $tview = Gtk2::TextView->new_with_buffer($buffer);
    $tview->set_cursor_visible(0);
    $tview->set_editable(0);
    $tview->set_justification("center");
    $tview->show;
    $frame->add($tview);
    #$hbox->pack_start($tview, 1, 1, 10);

    $self->add_sep
    (
        parent => $hbox,
        type => 'v',
    );

    $self->add_sep
    (
        parent => $vbox,
        type => 'h',
    );

    return $frame;
    return $vbox;
}

sub flash_label
{
    my ($self, $label, $flash) = @_;
    $self->display_error("needs work");
    return;

    $flash && $label->hide;
    $flash || $label->show;
    $flash = ! $flash;

    return 1;
}

# Simple List, ironic name
sub create_slist
{
    my ($self, %p) = @_;

    my $columns = delete $p{columns};
    $self->display_error("No slist columns")
        and return unless defined $columns;
    
    my $sizes = delete $p{sizes};
    my $set_sort = delete $p{set_sort} || 1;
    my $sel_mode = delete $p{sel_mode} || 'single';
    my $data = delete $p{data};
    my $add_color = delete $p{add_color} || 0;
    
    $self->add_color_column_to_slist if $add_color;

    my $slist = Gtk2::SimpleList->new(@$columns);
    $slist->get_selection->set_mode($sel_mode);
    @{ $slist->{data} } = @$data if defined $data;

    my $events = ( exists $p{events} )
    ? $self->utils->merge_events( $self->utils->default_slist_events, delete $p{events})
    : $self->utils->default_slist_events;
    $self->utils->add_events_to_widget($slist, $events);

    $slist->set_rules_hint(1);
    
    my $last_col = $slist->get_model->get_n_columns;
    $last_col-- if $add_color;
    my $color_col = $last_col;

    for (my $i = 0; $i < $last_col; $i++)
    {
        my $col = $slist->get_column($i);
        $col->set_sort_column_id($i) if $set_sort;
        $col->set_min_width(@$sizes[$i]) if defined $sizes;
        $col->add_attribute($col->get_cell_renderers, cell_background_gdk => $color_col) if $add_color;
    }

    $slist->show;

    return $slist;
}

sub add_slist
{
    my ($self, %p) = @_;

    $p{child} = $self->create_slist(%p);

    return $self->add_or_pack_child(%p);
}

1;

=pod

=head1 Name

 Gtk2Ext::PackingFactory
 
=head1 Synopsis

 This package provides a singleton for building and managing gtk2
  widgets.

=head1 Usage

 Basics:

 use Gtk2Ext::PackingFactory;

 my $view = Gtk2Ext::PackingFactory->instance(title => 'Hi', size => 100);
 # use instance, no new method!
 
 $view->init; # inits Gtk2

 my $win = $view->create_window(h => 200, v => 200);
 $view->add_label(parent => $win, text => 'Hello World');

 $view->start; # starts the main loop;
 
 $view->exit # when done;

=head1 Widget List

There are 2 main methods for each widget type:

>add_widget - creaes and adds the widget to the parent

>create_widget - creates the widget only

Both of these methods return the widget or sets the error_msg and return undef.
Each of the widget params are different.

=head1 Methods

=head2 add_or_pack_child
 
my $child  = $view->add_or_pack_child
(
  parent => $main_win, # req
  child => $vbox, # req
  expand => 1, # opt
  fill => 1, # opt
);
 
Returns the packed child, or undef on failure.
 
=head1 See Also
 
=over

=item Gtk2

=item Gtk2Ext classes

=item Finfo::Singleton

=back

=head1 Disclaimer

Copyright (C) 2007 Washington University Genome Sequencing Center

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
License for more details.

=head1 Author(s)

Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
