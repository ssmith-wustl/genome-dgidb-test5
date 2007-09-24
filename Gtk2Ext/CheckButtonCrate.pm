package Gtk2Ext::CheckButtonCrate;

use strict;
use warnings;

use base 'Gtk2Ext::ButtonCrate';

my %add_select_all :name(add_select_all:o) :default(1);

sub _add_buttons
{
    my $self = shift;

    if ( $self->add_select_all )
    {
        my $vbox = $self->factory->add_box
        (
            parent => $self->bbox,
            type => 'v',
            expand => 1,
            fill => 1,
        );
        
        #$self->factory->add_label(parent => $vbox, text => '');

        $self->factory->add_button
        (
            parent => $vbox,
            text => 'Select All',
            expand => 1,
            fill => 1,
            events => 
            {
                clicked => sub
                {
                    my $b = shift; 
                    if ( $b->get_label eq 'Select All' ) 
                    {
                        Gtk2Ext::Utils->select_all_check_buttons([ $self->get_buttons ]);
                        $b->set_label('Deselect All'); 
                    }
                    else 
                    {  
                        Gtk2Ext::Utils->deselect_all_check_buttons([ $self->get_buttons ]);
                        $b->set_label('Select All');
                    }
                }
            }
        );

        $self->_base_button_pos(1);
    }

    my $button_params = $self->button_params;
    foreach my $button ( @{ $self->button_params } )
    {
        $self->error_msg("No name for button")
            and return next unless defined $button->{name};

        $button->{label} = ucfirst($button->{name}) unless exists $button->{label};

        my $events = ( exists $button->{events} )
        ? $self->utils->merge_events($self->_default_event_handlers, $button->{events})
        : $self->_default_event_handlers;
 
        my $cb = $self->factory->add_check_button
        (
            parent => $self->bbox,
            text => $button->{label},
            color => $button->{color},
            active => $button->{active},
            events => $events,
        );

        $self->error_msg("Could not create check button for " . $button->{name})
            and return unless $cb;

        $self->_store_button($cb);

        if ( $button->{ecrates} )
        {
            $self->create_and_add_ecrates_to_button($button->{name}, $button->{ecrates})
                or return;
        }
    }

    return 1;
}

sub select_all_buttons
{
    my $self = shift;

    return Gtk2Ext::Utils->select_all_check_buttons([ $self->get_buttons ]);
}

sub deselect_all_buttons
{
    my $self = shift;

    return Gtk2Ext::Utils->deselect_all_check_buttons([ $self->get_buttons ]);
}

sub get_active_buttons
{
    my $self = shift;

    my @active_buttons = grep { $_->get_active } $self->get_buttons;

    return @active_buttons;
}

sub get_active_button_labels
{
    my $self = shift;

    my @active_buttons = $self->get_active_buttons
        or return;

    return map { $_->get_label } @active_buttons;
}

sub get_active_button_names
{
    my $self = shift;

    my @active_names = map 
    {
        $self->get_button_name_for_label($_->get_label) 
    } $self->get_active_buttons;

    return @active_names;
}

sub get_entered_values_in_ecrates_for_active_buttons
{
    my $self = shift;

    my @names = $self->get_active_button_names;

    return unless @names;

    my ($results, @errors);
    foreach my $name ( @names )
    {
        my ($return, $value) = $self->get_entered_values_in_ecrates_for_button_name($name);
        if ( $return )
        {
            $results->{$name} = $value->{$name};
        }
        else
        {
            push @errors, @$value;
        }
    }

    return ( @errors ) ? (0, \@errors) : (1, $results);
}

1;

=pod

=head1 Name

Gtk2Ext::CheckButtonCrate

=head1 Synopsis

CBC provides a manager for a group of radio buttons.  It creates and displays the radio buttons and their entry crates.  Then, the active buttons and entered values can be accessed easily.

=head1 Usage

  use Gtk::CheckButtonCrate;

  my $cbc = Gtk2Ext::CheckButtonCrate->new
  (
     buttons => # req - aryref of hashrefs representing each button with keys:
     [
     {
         name => $name, # the attribute name
         label => $label, # text in button, default is uc of the name
         ecrates => \@ecrates, # opt - aryref of ecrates
     }
     ],
     plane   => 'v', # opt - v for vertical box (default), h  for horizontal box
 );

 # pack it...
 $dialog->vbox->pack_start_defaults($cbc->bbox);

 B<Get active button names, etc>

 my @active_names = $cbc->get_active_button_names;

=head1 Methods - See Base Class Gtk2Ext::ButtonCrate for more methods

=head2 get_entered_values_in_ecrates_for_active_buttons

 my $values = $cbc->get_entered_values_in_ecrates_for_active_buttons;

 $values->{ $active_button_name1 } = { ec_name1 => ec_val1, etc };
 $values->{ $active_button_name2 } = { ec_name1 => ec_val1, etc };
 etc...

=over

=item I<Synopsis>   Determines the active buttons for the button crate, then gets the values of the entry crates for each one, validating the entered value.

=item I<Params>     none

=item I<Returns>    values (hashref with keys of active button names, values are hashrefs of ecrate names and ecrate entered values)

=back

=head2 get_active_buttons

 my @buttons = $cbc->get_active_buttons;

=over

=item I<Synopsis>   Determines and gets the active button for the button crate

=item I<Params>     none

=item I<Returns>    chack buttons (array of Gtk2::RadioButtons)

=back

=head2 get_active_button_names

 my @names = $cbc->get_active_button_names;

=over

=item I<Synopsis>   Determines and gets the active button names for the button crate

=item I<Params>     none

=item I<Returns>    names (array of strings)

=back

=head2 get_active_button_labels

 my @names = $cbc->get_active_button_labels;

=over

=item I<Synopsis>   Determines and gets the active button labels for the button crate

=item I<Params>     none

=item I<Returns>    labels (array of strings)

=back

=head2 select_all_buttons

 $cbc->select_all_buttons;

=over

=item I<Synopsis>   Selects all of the buttons in the check buttpn crate

=item I<Params>     none

=item I<Returns>    boolean

=back

=head2 deselect_all_buttons

 $cbc->deselect_all_buttons;
 
=over

=item I<Synopsis>   Deselects all of the buttons in the check button crate

=item I<Params>     none

=item I<Returns>    boolean

=back

=head1 Disclaimer

Copyright (C) 2007 Washington University Genome Sequencing Center

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
License for more details.

=head1 Author(s)

Edward A. Belter, Jr  <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
