package Gtk2Ext::ButtonCrate;

use strict;
use warnings;

use Finfo::Std;

use Data::Dumper;
use Gtk2Ext::EntryCrate;
use Gtk2Ext::PackingFactory;
use Gtk2Ext::Utils;

my %button_params :name(button_params:r)
    :ds(aryref)
    :access(ro);
my %orient :name(orient:o) 
    :isa('regex h v')
    :default('v')
    :access(ro);
my %buttons :name(_buttons:p)
    :ds(aryref)
    :empty_ok(1)
    :default([]);
my %ecrates :name(_ecrates:p)
    :ds(hashref)
    :empty_ok(1)
    :default({});
my %bbox :name(_bbox:p);
my %base_button_pos :name(_base_button_pos:p)
    :isa('int') 
    :default(0);

sub START
{
    my $self = shift;

    $self->_bbox
    (
        $self->factory->create_bbox
        (
            type => uc $self->orient,
            layout => ( $self->orient eq 'v' ) ? 'start' : 'spread',
            spacing => 10,
        )
    );

    $self->error_msg("Could not create button box")
        and return unless $self->_bbox;
    
    $self->_add_buttons
        or return;

    return 1;
}

sub factory
{
    return Gtk2Ext::PackingFactory->instance;
}

sub utils
{
    return Gtk2Ext::Utils->instance;
}

sub bbox
{
    my $self = shift;

    return $self->_bbox;
}

sub _store_button : RESTRICTED
{ 
    my ($self, @new_buttons) = @_;

    my $buttons = $self->_buttons;
    push @$buttons, @new_buttons if @new_buttons;
    $self->_buttons($buttons);

    return @{ $self->_buttons };
}

sub get_buttons
{
    return @{ shift->_buttons };
}

sub last_button
{
    my $self = shift;

    my @buttons = $self->get_buttons;
    
    return unless @buttons;
    
    return $buttons[$#buttons];
}

sub labels
{
    my $self = shift;

    return map { $_->get_label } $self->get_buttons;
}

# Gettin' button info for number
sub get_button_for_number
{
    my ($self, $num) = @_;

    my @buttons = $self->get_buttons;

    return unless Finfo::Validate->validate
    (
        name => 'button number',
        value => $num,
        type => 'int_between',
        options => [ 0, $#buttons ],
        err_cb => $self,
    );

    return $buttons[$num];
}

sub get_button_name_for_number
{
    my ($self, $num) = @_;

    my $button = $self->get_button_for_number($num)
        or return;
    
    return $self->get_button_name_for_label( $button->get_label );
}

sub get_button_label_for_number
{
    my ($self, $num) = @_;

    my $button = $self->get_button_for_number($num)
        or return;

    return $button->get_label;
}

# Gettin' button info for label
sub get_button_for_label
{
    my ($self, $label) = @_;

    $self->error_msg("No label sent to get button for")
        and return unless defined $label;
    
    foreach my $button ( $self->get_buttons )
    {
        return $button if $button->get_label eq $label;
    }

    $self->error_msg("No button found for name ($label)");
    
    return;
}

sub get_button_name_for_label
{
    my ($self, $label) = @_;

    $self->error_msg("No button label to get button name")
        and return unless defined $label;
    
    my ($button) = grep { $label eq $_->{label} } @{ $self->button_params };
    
    $self->error_msg("Can't find button name for button label ($label)")
        and return unless defined $button;

    return $button->{name};
}

sub get_button_number_for_label
{
    my ($self, $label) = @_;

    my $i = 0;
    foreach my $button ( $self->get_buttons )
    {
        return $i if $button->get_label eq $label;
        $i++;
    }

    $self->error_msg("Can't find button with label ($label)");

    return;
}

sub get_button_position_for_label
{
    my ($self, $label) = @_;

    $self->error_msg("No label to get button position")
        and return unless defined $label;
    
    my $i = $self->_base_button_pos;
    foreach my $button ( $self->get_buttons )
    {
        return $i if $button->get_label eq $label;
        $i++;
        my $current_ecrate_count = scalar($self->get_button_ecrates_for_label($button->get_label)) || 0;
        $i += $current_ecrate_count;
    }

    $self->error_msg("Can't find button for label ($label)");

    return;
}

# Gettin' button info for name
sub get_button_for_name
{
    my ($self, $name) = @_;

    $self->error_msg("No label sent to get button for")
        and return unless defined $name;
    
    my $label;
    foreach my $button ( @{ $self->button_params } )
    {
        if ( $button->{name} eq $name )
        {
            $label = $button->{label};
            last;
        }
    }

    $self->error_msg("No button found for name ($name)") 
        and return unless defined $label;

    return $self->get_button_for_label($label);
}

sub get_button_number_for_name
{
    my ($self, $name) = @_;

    my $button = $self->get_button_for_name($name)
        or return;

    return $self->get_button_number_for_label( $button->get_label );
}

sub get_button_label_for_name
{
    my ($self, $name) = @_;

    my $button = $self->get_button_for_name($name)
        or return;

    return $button->get_label;
}

sub get_button_position_for_name
{
    my ($self, $name) = @_;

    my $label = $self->get_button_label_for_name($name)
        or return;

    return $self->get_button_position_for_label($label);
}

#ecrates
sub add_ecrates_to_button
{
    my ($self, $name, @ecrates) = @_;

    Finfo::Validate->validate
    (
        attr => 'button name',
        value => $name,
        type => 'string',
        err_cb => $self,
    );

    my $button = $self->get_button_for_name($name)
        or return;

    $self->error_msg("No ecrates to add to button ($name)")
        and return unless @ecrates;
    
    my $button_pos = $self->get_button_position_for_name($name);

    my $current_ecrate_count = scalar $self->get_button_ecrates_for_name($name) || 0;

    my $pos = $button_pos + $current_ecrate_count;
    
    foreach my $ecrate ( @ecrates )
    {
        $pos++;
        
        $ecrate->box->hide unless $button->get_active;
        $self->bbox->pack_start($ecrate->box, 0, 0, 10);
        $self->bbox->reorder_child( $ecrate->box, $pos );
    }
    
    my $buttons_ecrates = $self->_ecrates;
    $buttons_ecrates->{$name} = \@ecrates;
    $self->_ecrates($buttons_ecrates);
    
    return @ecrates;
}

sub create_and_add_ecrates_to_button
{
    my ($self, $name, $ec_refs) = @_;
    
    Finfo::Validate->validate
    (
        attr => 'button name',
        value => $name,
        type => 'string',
        err_cb => $self,
    );

    Finfo::Validate->validate
    (
        attr => 'ecrate params to add to button',
        value => $ec_refs,
        type => 'non_empty_aryref',
        ref_type => 'hashref',
        err_cb => $self,
    );
    
    my @ecrates;
    foreach my $ec_ref ( @$ec_refs )
    {
        $self->error_msg("Invalid ecrate ref:\n" . Dumper($ec_ref))
            and return unless ref $ec_ref eq 'HASH';
        push @ecrates, Gtk2Ext::EntryCrate->new(%$ec_ref);
    }
    
    return $self->add_ecrates_to_button($name, @ecrates)
}

sub get_button_ecrates_for_name
{
    my ($self, $name) = @_;
    
    $self->error_msg("no name sent to get ecrates for button")
        and  return unless defined $name;
    
    my $ecrates = $self->_ecrates;

    return unless exists $ecrates->{$name};

    return @{ $ecrates->{$name} };
}

sub get_button_ecrates_for_label
{
    my ($self, $label) = @_;
    
    $self->error_msg("no label sent to get ecrates for button")
        and  return unless defined $label;
    
    my $name = $self->get_button_name_for_label($label)
        or return;

    my $ecrates = $self->_ecrates;

    return unless exists $ecrates->{$name};

    return @{ $ecrates->{$name} };
}

sub get_entered_values_in_ecrates_for_button_name
{
    my ($self, $name) = @_;

    $self->error_msg("No name sent to get ecrates for button")
        and  return unless defined $name;

    my $label = $self->get_button_label_for_name($name);
    
    my ($value, @errors);
    $value->{$name} = {};
    foreach my $ecrate ( $self->get_button_ecrates_for_name($name) )
    {
        $value->{$name}->{ $ecrate->name } = $ecrate->get_entered_value
            or push @errors, $ecrate->short_error_msg." for button '$label'";
    }

    return ( @errors ) ? (0, \@errors) : (1, $value);
}

# set active
sub set_button_active_by_num
{
    my ($self, $num) = @_;

    my $name = $self->get_button_name_for_number($num);

    my $button = $self->get_button_for_name($name)
        or return;

    return $button->set_active(1);
}

sub set_button_active_by_label
{
    my ($self, $label) = @_;

    my $button = $self->get_button_for_label($label)
        or return;

    return $button->set_active(1);
}

sub set_button_active_by_name
{
    my ($self, $name) = @_;

    my $button = $self->get_button_for_name($name)
        or return;

    return $button->set_active(1);
}

# default events
sub _default_event_handlers
{
    my $self = shift;

    return
    {
        toggled => sub
        {
            my $b = shift;

            return unless $self->get_button_ecrates_for_label( $b->get_label );

            if ($b->get_active)
            {
                map { $_->box->show } $self->get_button_ecrates_for_label( $b->get_label );
            }
            else
            {
                map { $_->box->hide } $self->get_button_ecrates_for_label( $b->get_label );
            }
        }
    }
}

1;

=pod

=head1 Name

Gtk2Ext::ButtonCrate

=head1 Synopsis

B<Base class> for creating and managing buttons and button boxes.  Listed below are the generic methods for ButtonCrates.  See sub classes for additional methods.

=head1 Methods

=head2 bbox

 my $bbox = $bc->bbox;
 $bbox->hide;

I<or>

 $window->add($bc->bbox);

=over

=item I<Synopsis>   Gives access to the button box that the buttons are packed in

=item I<Params>     none

=item I<Returns>    Gtk2::ButtonBox (object, scalar)

=back

=head2 get_buttons

 my @buttons = $bc->get_buttons;

=over

=item I<Synopsis>   gets the buttons

=item I<Params>     none

=item I<Returns>    buttons (Gtk2::Button, array)

=back

=head2 last_button

 my $button = $bc->last_button;

=over

=item I<Synopsis>   gets the last button

=item I<Params>     none

=item I<Returns>    button (Gtk2::Button)

=back

=head2 labels

  my @labels = $crate->labels;

=over

=item I<Synopsis>   Gets the labels of the buttons

=item I<Params>     none

=item I<Returns>    button labels (array of strings)

=back

=head2 get_button_for_name

 my $button = $bc->get_button_for_name($name);

=over

=item I<Synopsis>   Gets the button for $name

=item I<Params>     name (string)

=item I<Returns>    button (Gtk2::Button)

=back

=head2 get_button_label_for_name

 my $label = $bc->get_button_label_for_name($name)
 
=over

=item I<Synopsis>   Gets the label for the button with $name

=item I<Params>     name (string)

=item I<Returns>    label (string)

=back

=head2 get_button_position_for_name

 my $pos = $bc->get_button_position_for_name($name);

=over

=item I<Synopsis>   Gets the position of the button in the button box for $name.  This takes in account the ecrates (hidden or not) of buttons that are above/in front of the requested button.

=item I<Params>     button name (string)

=item I<Returns>    button position (int)

=back

=head2 get_button_number_for_name

 my $num = $bc->get_button_number_for_name($name);

=over

=item I<Synopsis>   Gets the button number (array index), not position, for the button name

=item I<Params>     name (string)

=item I<Returns>    number (int)

=back

=head2 get_button_for_label

 my $button = $bc->get_button_for_label($label);

=over

=item I<Synopsis>   Gets the button for $label

=item I<Params>     label (string)

=item I<Returns>    button (Gtk2::Button)

=back

=head2 get_button_name_for_label

 my $label = $bc->get_button_name_for_label($label)
 
=over

=item I<Synopsis>   Gets the label for the button with $label

=item I<Params>     label (string)

=item I<Returns>    name (string)

=back

=head2 get_button_position_for_label

 my $pos = $bc->get_button_position_for_label($label);

=over

=item I<Synopsis>   Gets the position of the button in the button box for $label.  This takes in account the ecrates (hidden or not) of buttons that are above/in front of the requested button.

=item I<Params>     label (string)

=item I<Returns>    position (int)

=back

=head2 get_button_number_for_label

 my $num = $bc->get_button_number_for_label($label);

=over

=item I<Synopsis>   Gets the button number (array index), not position, for $label 

=item I<Params>     label (string)

=item I<Returns>    number (int)

=back

=head2 get_button_for_number

 my $button = $bc->get_button_for_number($number);

=over

=item I<Synopsis>   Gets the button for $number

=item I<Params>     number (int)

=item I<Returns>    button (Gtk2::Button)

=back

=head2 get_button_label_for_number

 my $label = $bc->get_button_label_for_number($number)
 
=over

=item I<Synopsis>   Gets the label for the button with $number

=item I<Params>     number (int)

=item I<Returns>    label (string)

=back

=head2 get_button_number_for_number

 my $num = $bc->get_button_number_for_number($number);

=over

=item I<Synopsis>   Gets the button name

=item I<Params>     number (int)

=item I<Returns>    name (string)

=back

=head2 add_ecrates_to_button

 $bc->add_ecrates_to_button($name, @ecrates);

=over

=item I<Synopsis>   Add Gtk2Ext::EntryCrate's to a button with $name

=item I<Params>     name (string, scalar), ecrates (Gtk2Ext::EntryCrate, array)

=item I<Returns>    boolean

=back

=head2 get_button_ecrates_for_name

 my @ecrates = $bc->get_button_for_name($name);

=over

=item I<Synopsis>   Gets the ecrates for the button name

=item I<Params>     name

=item I<Returns>    ecrates for button (array of Gtk2Ext::EntryCrate)

=back

=head2 get_button_ecrates_for_label

 my @ecrates = $bc->get_button_for_label($label);

=over

=item I<Synopsis>   Gets the ecrates for the button label

=item I<Params>     label (strign)

=item I<Returns>    ecrates for button (array of Gtk2Ext::EntryCrate)

=back

=head2 create_and_add_ecrates_to_button

=over

=item I<Synopsis>   Gets the ecrates for the button label

=item I<Params>     label (strign)

=item I<Returns>    ecrates for button (array of Gtk2Ext::EntryCrate)

=back

=head2 get_entered_values_in_ecrates_for_button_name

 my $ref = $bc->get_entered_values_in_ecrates_for_button_name

=over

=item I<Synopsis>   Gets the ecrates for the button label

=item I<Params>     label (strign)

=item I<Returns>    ecrates for button (array of Gtk2Ext::EntryCrate)

=back

=head2 set_button_active_by_label

 $bc->set_button_active_by_label($label);

=over

=item I<Synopsis>   Sets the button with $label to active

=item I<Params>     label (string)

=item I<Returns>    boolean

=back

=head2 set_button_active_by_num

 $bc->set_button_active_by_num($num);

=over

=item I<Synopsis>   Sets the button with $num to active

=item I<Params>     number (int)

=item I<Returns>    boolean

=back

=head2 set_button_active_by_name

 $bc->set_button_active_by_name($name);

=over

=item I<Synopsis>   Sets the button with $name to active

=item I<Params>     name (string)

=item I<Returns>    boolean

=back

=head1 Disclaimer

Copyright (C) 2006-2007 Washington University Genome Sequencing Center

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
License for more details.

=head1 AUTHOR

B<Edward A. Belter, Jr.>  <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
