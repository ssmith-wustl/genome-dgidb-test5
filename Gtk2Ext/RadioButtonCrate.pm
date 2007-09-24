package Gtk2Ext::RadioButtonCrate;

use strict;
use warnings;

use base 'Gtk2Ext::ButtonCrate';

use Data::Dumper;

sub get_group
{
    my $self = shift;

    my @buttons = $self->get_buttons;

    return undef unless @buttons;

    return $buttons[0]->get_group;
}

sub _add_buttons
{
    my $self = shift;

    foreach my $button ( @{ $self->button_params } )
    {
        $self->error_msg("No name for button")
            and return unless exists $button->{name};

        $button->{label} = ucfirst($button->{name}) unless exists $button->{label};

        my $events = ( exists $button->{events} )
        ? $self->utils->merge_events($self->_default_event_handlers, $button->{events})
        : $self->_default_event_handlers;

        my $rb = $self->factory->add_radio_button
        (
            parent => $self->bbox,
            text => $button->{label},
            group => $self->get_group,
            color => $button->{color},
            events => $events,
        );

        $self->error_msg("Could not create check button ($button->{name})")
            and return unless $rb;

        $self->_store_button($rb);

        if ( $button->{ecrates} )
        {
           $self->create_and_add_ecrates_to_button($button->{name}, $button->{ecrates})
               or return;
        }

        $rb->show;
    }

    return 1;
}

sub get_active_button
{
    my $self = shift;

    foreach my $button ( $self->get_buttons )
    {
        return $button if $button->get_active;
    }

    return;
}

sub get_active_button_name
{
    my $self = shift;

    return $self->get_button_name_for_label( $self->get_active_button->get_label );
}

sub get_active_button_label
{
    my $self = shift;

    return $self->get_active_button->get_label;
}

sub get_entered_values_in_ecrates_for_active_button
{
    my $self = shift;

    my $name = $self->get_active_button_name;

    return $self->get_entered_values_in_ecrates_for_button_name($name);
    # (return_value(TRUE-success/FALSE-errors), value/errors)
}

1;

=pod

=head1 Name

Gtk2Ext::RadioButtonCrate

=head1 Synopsis

RBC provides a manager for a group of radio buttons.  It creates and displays the radio buttons and their entry crates.  Then, the active button and entered values can be accessed easily.

=head1 Usage

 use Gtk::ButtonCrate::Radio;

 my $rbc = Gtk2Ext::RadioButtonCrate->new
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
 $dialog->vbox->pack_start_defaults($rbc->bbox);

 B<Get active button name, etc>

 my $active_name = $rbc->get_active_button_name;

=head1 Methods - See Base Class Gtk2Ext::ButtonCrate for more methods

=head2 get_active_button

 my $rb = $rbc->get_active_button;

=over

=item I<Synopsis>   Determines and gets the active button for the button crate

=item I<Params>     none

=item I<Returns>    radio button (Gtk2::RadioButton)

=back

=head2 get_active_button_name

 my $name = $rbc->get_active_button_name;

=over

=item I<Synopsis>   Determines and gets the active button name for the button crate

=item I<Params>     none

=item I<Returns>    name (string)

=back

=head2 get_active_button_label

 my $label = $rbc->get_active_button_label;

=over

=item I<Synopsis>   Determines and gets the active button label for the button crate

=item I<Params>     none

=item I<Returns>    label (string)

=back

=head2 get_entered_values_in_ecrates_for_active_button

 my $values = $rbc->get_entered_values_in_ecrates_for_active_button;

 $values->{ $active_button_name } = { ec_name1 => ec_val1, etc };

=over

=item I<Synopsis>   Determines the active button for the button crate and reutrns its name

=item I<Params>     none

=item I<Returns>    values (hashref with key of active button name, values are hashrefs of ecrate names and ecrate entered values)

=back

=head1 Disclaimer

Copyright (C) 2006-7 Washington University Genome Sequencing Center

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
License for more details.

=head1 Author(s)

Edward A. Belter, Jr  <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
