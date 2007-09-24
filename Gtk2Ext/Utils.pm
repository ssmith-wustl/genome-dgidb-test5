package Gtk2Ext::Utils;

use strict;
use warnings;

use base 'Finfo::Singleton';

use Gtk2 -init;

use Data::Dumper;
use Gtk2::SimpleList;
use Gtk2Ext::Info;
use IO::File;

sub gtk2_init
{
    Gtk2->set_locale;
    Gtk2->init;
}

sub gtk2_main
{
    Gtk2->main;
}

sub gtk2_quit
{
    Gtk2->main_quit;
}

# Window/Dialog stuff
sub waiting_cursor
{
    my ($self, $win, $cursor_type) = @_;

    Finfo::Validate->validate
    (
        attr => 'window to set waitng cursor',
        value => $win,
        type => 'inherits_from',
        options => [qw/ Gtk2::Window /],
        err_cb => $self,
    );
    
    $cursor_type = (defined $cursor_type)
    ? $cursor_type
    : "left-ptr";

    $win->window->set_cursor( Gtk2::Gdk::Cursor->new("watch") );

    my $mainloop = Glib::MainLoop->new();
    Glib::Timeout->add
    (
        100,
        sub
        {
            $mainloop->quit; 
            $win->window->set_cursor( Gtk2::Gdk::Cursor->new($cursor_type) );
            return 0;
        }
    );

    return $mainloop->run;
}

# Events
sub add_events_to_widget
{
    my ($self, $widget, $events) = @_;

    $self->_enforce_instance;

    Finfo::Validate->validate
    (
        attr => 'widget to add events',
        value => $widget,
        type => 'object',
        err_cb => $self,
    );

    Finfo::Validate->validate
    (
        attr => 'events to add to widget',
        value => $events,
        type => 'non_empty_hashref',
        err_cb => $self,
    );

    while ( my ($sig, $cb) = each %$events )
    {
        $widget->signal_connect($sig, $cb)
            or die;
    }

    return 1;
}

sub merge_events
{
    my ($self, @events) = @_;

    $self->_enforce_instance;

    my %merged_events;
    foreach my $event ( @events )
    {
        Finfo::Validate->validate
        (
            attr => 'event to merge',
            value => $event,
            type => 'non_empty_hashref',
            err_cb => $self,
        );

        while ( my ($signal, $cb) = each %$event )
        {
            if ( exists $merged_events{$signal} )
            {
                my $old_cb = $merged_events{$signal};
                $merged_events{$signal} = sub{ $old_cb->(@_); $cb->(@_); }
            }
            else
            {
                $merged_events{$signal} = $cb;
            }
        }
    }

    return \%merged_events;
}

# Buttons
sub select_all_check_buttons
{
    my ($self, $buttons) = @_;

    Finfo::Validate->validate
    (
        attr => 'check buttons',
        value => $buttons,
        type => 'non_empty_aryref',
        err_cb => $self,
    );
    
    return map { $_->set_active(1) } @$buttons;
}

sub deselect_all_check_buttons
{
    my ($self, $buttons) = @_;

    Finfo::Validate->validate
    (
        attr => 'check buttons',
        value => $buttons,
        type => 'non_empty_aryref',
        err_cb => $self,
    );
    
    return map { $_->set_active(0) } @$buttons;
}

# Color
sub create_color
{
    my ($self, $color) = @_;
    
    if ( ref $color eq 'ARRAY' )
    {
        return Gtk2::Gdk::Color->new(@$color);
    }
    else
    {
        return Gtk2::Gdk::Color->parse($color);
    }
}

sub add_color_to_widget
{
    my ($self, %p) = @_;

    my $widget = delete $p{widget};

    Finfo::Validate->validate
    (
        attr => 'widget to add color',
        value => $widget,
        type => 'object',
        err_cb => $self,
    );
    
    my @layers = Gtk2Ext::Info->instance->widget_layers;
    my @state_types = Gtk2Ext::Info->instance->state_types;

    if ( my $all = delete $p{all} )
    {
        foreach my $layer ( @layers )
        {
            $p{$layer} = $all;
        }
    }
    
    foreach my $layer ( @layers )
    {
        my $layer_params = delete $p{$layer}
            or next;

        my $color;
        my @states = @state_types;
        if ( ref($layer_params) eq 'HASH' )
        {
            $color = $layer_params->{color};
            @states = @{ $layer_params->{states} } if exists $layer_params->{states};
        }
        else
        {
            $color = $layer_params;
        }
        
        my $gdk_color = $self->create_color( $color );
        $self->warn_msg("Can't crete color for " . Dumper($color))
            and return unless $gdk_color;

        foreach my $state ( @states )
        {
            my $method = 'modify_' . $layer;
            $widget->$method($state, $gdk_color);
        }
    }

    $self->fatal_msg("Unknown params sent to add_color_to_widget: " . join(', ', keys %p))
        and return if %p;

    return 1;
}

# Simple List
sub get_slist_column_titles
{
    my ($self, $slist) = @_;

    my @titles;
    my $last_col = $slist->get_model->get_n_columns;
    for (my $i = 0; $i < $last_col; $i++)
    {
        my $col = $slist->get_column($i);
        push @titles, $col->get_title;
    }
    
    return \@titles;
}

sub get_slist_data_in_column
{
    my ($self, $slist, $col) = @_;

    return map { $_->[$col] } @{ $slist->{data} };
}

sub get_slist_data_for_match
{
    my ($self, $slist, $match, $col) = @_;

    return grep { $_->[$col] eq $match } @{ $slist->{data} };
}

sub find_indices_for_column_match
{
    my ($self, $slist, $match, $col) = @_;

    my @indices; 
    my $length = scalar @{ $slist->{data} };
    for (my $i = 0; $i < $length; $i++)
    {
        push @indices, $i if $slist->{data}[$i]->[$col] eq $match;
    }
    
    return @indices;
}

sub get_data_for_column_from_indices
{
    my ($self, $slist, $indices, $col) = @_;

    return map { $slist->{data}[$_]->[$col] } @$indices;
}

sub get_slist_selected_indices
{
    my ($self, $slist) = @_;

    $self->fatal_msg("No slist")
        and return unless $slist;

    return $slist->get_selected_indices;
}

sub get_slist_selected_data
{
    my ($self, $slist, $col) = @_;

    my @sels = $self->get_slist_selected_indices($slist)
        or return;

    # TODO add multiple column support?
    return map { $slist->{data}[$_]->[$col] } @sels if defined $col;
        
    return map { $slist->{data}[$_] } @sels
}

sub get_slist_selected_data_as_delineated_string
{
    my ($self, $slist, $char, $col) = @_;

    my @data = $self->get_slist_selected_data($slist, $col)
        or return;
    
    return $self->_convert_slist_data_to_string($slist, \@data, $char);
}

sub get_all_slist_data_as_delineated_string
{
    my ($self, $slist, $char, $col) = @_;

    my $data = ( defined $col )
    ? [ $slist->get_slist_data_in_column($slist, $col) ]
    : $slist->{data};

    return unless @$data;
    
    return $self->_convert_slist_data_to_string($slist, $data, $char);
}

sub _convert_slist_data_to_string : PRIVATE
{
    my ($self, $slist, $data, $char) = @_;

    $char = '\t' unless defined $char;
    
    my $text = join($char, @{ $self->get_slist_column_titles($slist) }) . "\n";
    foreach my $data ( @$data )
    {
        $text .= sprintf("%s\n", join($char, ( ref($data) ) ? @$data : $data));
    }
    
    return $text;
}

sub add_slist_data
{    
    my ($self, $slist, @aryrefs) = @_;
    
    return push @{ $slist->{data} }, @aryrefs;
}

sub move_slist_data
{
    my ($self, $from, $to, $matches, $col) = @_;

    $col = 0 unless defined $col;
    
    my $length = scalar @{ $from->{data} };
    for (my $i = 0; $i < $length; $i++)
    {
        next unless grep { @{ $from->{data} }[$i]->[$col] eq $_ } @$matches;
        push @{ $to->{data} }, splice ( @{ $from->{data} }, $i, 1);
        $length--;
        $i--;
    }
    
    return 1;
}

sub remove_slist_data
{
    my ($self, $slist, $row) = @_;
    
    return splice @{ $slist->{data} }, $row, 1;
}

sub remove_slist_data_by_col_match
{
    my ($self, $slist, $matches, $col) = @_;

    $col = 0 unless defined $col;

    my $length = scalar @{ $slist->{data} };
    for (my $i = 0; $i < $length; $i++)
    {
        next unless grep { @{ $slist->{data} }[$i]->[$col] eq $_ } @$matches;
        splice ( @{ $slist->{data} }, $i, 1);
        $length--;
        $i--;
    }

    return;
}

sub remove_all_slist_data
{
    my ($self, $slist) = @_;

    return splice @{ $slist->{data} }, 0;
}

sub replace_slist_data
{
    my ($self, $slist, $aryref, $row) = @_;

    return splice @{ $slist->{data} }, $row, 1, $aryref;
}

sub default_slist_events
{
    my $self = shift;

    return 
    {
        button_press_event => sub
        {
            my ($slist, $event) = @_;

            my $button = $event->button;

            if ( $button eq 1 )
            {
                # ignore
                return 0;
            }
            elsif ( $button eq 2 )
            {
                # ignore
                return 0;
            }
            elsif ( $button eq 3 )
            {
                my $menu = Gtk2::Menu->new();

                my @signals_and_cbs = 
                (
                    {
                        name => 'print all rows to screen',
                        img => 'gtk-print',
                        cb => sub
                        {
                            my $str = $self->get_all_slist_data_as_delineated_string($slist, ',')
                                or return;
                            print "$str\n";
                        },
                    },
                    {
                        name => 'print selected rows to screen',
                        img => 'gtk-print',
                        cb => sub
                        {
                            my $str = $self->get_slist_selected_data_as_delineated_string($slist, ',')
                                or return;
                            print "$str\n";
                        },
                    },
                    {
                        name => 'save all rows to file',
                        img => 'gtk-save',
                        cb => sub
                        { 
                            my $str = $self->get_all_slist_data_as_delineated_string($slist, ',')
                                or return;
                            $self->save_text_to_file(text => $str);
                        },
                    },
                    {
                        name => 'save selected rows to file',
                        img => 'gtk-save',
                        cb => => sub
                        { 
                            #TODO check for selected data
                            my $str = $self->get_slist_selected_data_as_delineated_string($slist, ',')
                                or return;
                            $self->save_text_to_file(text => $str);
                        },
                    },
                );

                foreach my $sig_and_cb ( @signals_and_cbs )
                {
                    my $item = Gtk2::ImageMenuItem->new($sig_and_cb->{name});
                    my $img = Gtk2::Image->new_from_stock($sig_and_cb->{img}, 'menu');
                    $item->set_image($img);
                    $item->signal_connect('activate', $sig_and_cb->{cb});
                    $item->show;
                    $menu->append($item);
                }

                $menu->popup(undef, undef, undef, undef, $event->button, $event->time);

                return 1; # returning true discontinues other callbacks
            }
            else
            {
                # shouldn't get here
            }
        }
    }
}

sub add_color_column_to_slist
{
    return Gtk2::SimpleList->add_column_type
    (
        'color',
        type     => 'Gtk2::Gdk::Color',
        renderer => 'Gtk2::CellRendererText',   
        attr     => 'hidden',
    );
}

# file
sub save_file
{
    my ($self, $file, $text) = @_;

    return unless Finfo::Validate->validate
    (
        attr => 'text to save',
        value => $text,
        type => 'defined',
        err_cb => $self,
    );

    return unless Finfo::Validate->validate
    (
        attr => 'file to save text to',
        value => $file,
        type => 'output_file',
        err_cb => $self,
    );
    
    my $fh = IO::File->new("> $file");
    Gtk2Ext::Dialogs->instance->error_dialog("Could not open $file for writing: $!")
        and return unless $fh;
    $fh->print($text);
    $fh->close;

    Gtk2Ext::Dialogs->instance->error_dialog("File was not saved\:$!")
        and return unless -e $file;

    Gtk2Ext::Dialogs->instance->info_dialog("File Saved!");

    return 1;
}

sub save_text_to_file
{
    my ($self, %p) = @_;

    my $file = Gtk2Ext::Dialogs->instance->file_dialog
    (
        title => $p{title},
        dir => $p{dir},
        type => 'new',
    );

    return 1 unless defined $file;

    return $self->save_file($file, $p{text});
}

1;

=pod

=head1 Name

Gtk2Ext::Utils

=head1 Synopsis

Utility methods for Gtk2

=head1 Usage

 use Gtk2Ext::Utils;

 # get the instance
 my $utils = Gtk2Ext::Utils->instance;

 # execute a method
 $utils->add_events_to_widget($widget, $events);
 
 # execute a method thru the instance
 Gtk2Ext::Utils->instance->add_events_to_widget($widget, $events);
 
=head1 Methods

=head2 gtk2_main

Gtk2Ext::Utils->instance->gtk2_main();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 gtk2_exit

Gtk2Ext::Utils->instance->gtk2_exit();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 waiting_cursor

 Gtk2Ext::Utils->instance->waiting_cursor($window, $cursor);

=over

=item I<Synopsis>   creates a waiting cursor, while waiting for another event

=item I<Params>     Gtk2::Window (object), cursor (string) - cursor to set back after pause

=item I<Returns>    boolean

=back

=head2 add_events_to_widget

Gtk2Ext::Utils->instance->add_events_to_widget($widget, $events);

=over

=item I<Synopsis>   Add events to a widget

=item I<Params>     Gtk2::* widget, events (hashref of keys-signals, values-callbacks)

=item I<Returns>    boolean

=back

=head2 merge_events

 my $merged events = Gtk2Ext::Utils->instance->merge_events(@events);

=over

=item I<Synopsis>   Takes a list of events, then concatenates them based on the signals

=item I<Params>     events (array of hashrefs keys-signals(strings), values-callbacks(code))

=item I<Returns>    events (hashref keys-signals(strings), values-callbacks(code))

=back

=head2 select_all_check_buttons

Gtk2Ext::Utils->instance->select_all_check_buttons(@check_buttons);

=over

=item I<Synopsis>   Toggles the check buttons

=item I<Params>     Gtk2::CheckButtons (array of objects)

=item I<Returns>    boolean

=back

=head2 deselect_all_check_buttons

Gtk2Ext::Utils->instance->deselect_all_check_buttons();

=over

=item I<Synopsis>   Un-toggles the check buttons

=item I<Params>     Gtk2::CheckButtons (array of objects)

=item I<Returns>    boolean

=back

=head2 create_color

 my $gdk_color = Gtk2Ext::Utils->instance->create_color();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 add_color_to_widget

Gtk2Ext::Utils->instance->add_color_to_widget();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 get_slist_column_titles

 my $titles = Gtk2Ext::Utils->instance->get_slist_column_titles($slist);

=over

=item I<Synopsis>

=item I<Params>     Gtk2::SimpleList (object)

=item I<Returns>    titles (aryref of strings)

=back

=head2 get_slist_data_in_column

 my $data = Gtk2Ext::Utils->instance->get_slist_data_in_column($slist, $col_num);

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 get_slist_data_for_match

Gtk2Ext::Utils->instance->get_slist_data_for_match();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 find_indices_for_column_match

Gtk2Ext::Utils->instance->find_indices_for_column_match();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 get_data_for_column_from_indices

Gtk2Ext::Utils->instance->get_data_for_column_from_indices();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 get_slist_selected_data

Gtk2Ext::Utils->instance->get_slist_selected_data();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 get_slist_selected_indices

Gtk2Ext::Utils->instance->get_slist_selected_indices();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 convert_slist_selected_indices_to_string

Gtk2Ext::Utils->instance->convert_slist_selected_indices_to_string();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 add_slist_data

Gtk2Ext::Utils->instance->add_slist_data();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 move_slist_data

Gtk2Ext::Utils->instance->move_slist_data();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 remove_slist_data

Gtk2Ext::Utils->instance->remove_slist_data();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 remove_slist_data_by_col_match

Gtk2Ext::Utils->instance->remove_slist_data_by_col_match();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 remove_all_slist_data

Gtk2Ext::Utils->instance->remove_all_slist_data();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 replace_slist_data

Gtk2Ext::Utils->instance->replace_slist_data();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 save_file

Gtk2Ext::Utils->instance->save_file();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 save_text_to_file

Gtk2Ext::Utils->instance->save_text_to_file();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head1 See Also

=over

=item Gtk2

=item Finfo::Singleton

=back

=head1 Disclaimer

Copyright (C) 2007 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
License for more details.

=head1 Author(s)

Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
