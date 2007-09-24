package Gtk2Ext::Info;

use strict;
use warnings;

use base 'Finfo::Singleton';

use Data::Dumper;
use IO::File;
use Gtk2;

# general
sub default_title
{
    return 'Perl Gtk2';
}

# dialogs
sub dialog_flags
{
    return (qw/ modal destory-with-parent no-separator /);
}

sub msg_dialog_types
{
    return (qw/ info warning error question /);
}

sub _dialog_buttons_params : PRIVATE
{
    return 
    { 
        'close' => [qw/ gtk-close close /],
        cancel => [qw/ gtk-cancel  cancel /],
        ok => [qw/ gtk-ok ok /],
        save => [qw/ gtk-save accept /], # 'save' GtkResponseType does not exist
        apply => [qw/ gtk-apply apply /],
        reject => [qw/ gtk-reject reject /],
        'accept' => [qw/ gtk-accept accept /],
        yes =>  => [qw/ gtk-yes yes /],
        no =>  => [qw/ gtk-no no /],
        help => [qw/ gtk-help help /],

    };
}

sub valid_dialog_buttons
{
    return keys %{ (_dialog_buttons_params()) };
}

sub default_dialog_button
{
    return 'close';
}

sub default_dialog_button_params
{
    my $self = shift;

    return $self->dialog_button_params_for_buttons([ default_dialog_button() ]);
}

sub dialog_button_params_for_buttons
{
    my ($self, $buttons) = @_;

    Finfo::Validate->validate
    (
        attr => "buttons to get button params",
        value => $buttons,
        type => 'non_empty_aryref',
        err_cb => $self,
    );

    my $buttons_params = $self->_dialog_buttons_params;

    my @bps;
    foreach my $button ( @$buttons )
    {
        $self->fatal_msg("Invalid button name ($button)") unless exists $buttons_params->{$button};

        push @bps, @{ $buttons_params->{$button} };
    }

    return @bps;
}

sub window_positions
{
    return (qw/ none center mouse center-always center-on-parent /);
}

sub stock_ids
{
    return sort Gtk2::Stock->list_ids;
}

sub state_types
{
    return (qw/ normal active prelight selected insensitive /);
}

sub widget_layers
{
    return (qw/ bg fg text base /);
}

sub color_file
{
    return "/etc/X11/rgb.txt";
}

sub colors
{
    my $self = shift;

    $self->_enforce_instance;

    my $file = $self->color_file;
    my $fh = IO::File->new("< $file");
    $self->fatal_msg("Can't open color file ($file): $!") unless $fh;

    my @colors;
    foreach my $line ($fh->getlines)
    {
        chomp $line;
        next unless $line =~ /^\d/;
        my ($red, $blue, $green, @name_tokens) = split(/\s+/, $line);
        push @colors,
        {
            red => $red * 257,
            green => $green * 257,
            blue => $blue * 257,
            name => join(' ', @name_tokens),
        };
    }
    $fh->close;

    return @colors;
}

1;

=pod

=head1 Name

Gtk2Ext::Info

=head1 Synopsis

Holds information about Gtk2 and it widgets

=head1 Usage

 use Gtk2Ext::Info;

 # get the instance, set the title
 my $info = Gtk2Ext::Info->instance;

 # execute a method
 my $title = $info->default_title;
 
 # execute a method thru the instance
 Gtk2Ext::Info->instance->
 
=head1 Methods

=head2 default_title

 my $title = Gtk2Ext::Info->instance->default_title;

=over

=item I<Synopsis>   Gets the default title

=item I<Params>     none

=item I<Returns>    title (string)

=back

=head2 dialog_flags

 my @flags = Gtk2Ext::Info->instance->dialog_flags();

=over

=item I<Synopsis>   Gets the dialog flags for a Gtk2::Dialog

=item I<Params>     none

=item I<Returns>    gtk2 dialog flags (arry of strings)

=back

=head2 msg_dialog_types

 my @msg_types = Gtk2Ext::Info->instance->msg_dialog_types;

=over

=item I<Synopsis>   Gets the type of message dialogs

=item I<Params>     none

=item I<Returns>    gtk2 msg dialog types (arry of strings)

=back

=head2 valid_dialog_buttons

 my @dialog_buttons = Gtk2Ext::Info->instance->valid_dialog_buttons;

=over

=item I<Synopsis>   Gets the valid dialog button names

=item I<Params>     none

=item I<Returns>    button names (array of strings)

=back

=head2 default_dialog_button

 my $button_name = Gtk2Ext::Info->instance->default_dialog_button();

=over

=item I<Synopsis>   Gets the default dialog button name

=item I<Params>     none

=item I<Returns>    button name (string)

=back

=head2 default_dialog_button_params

 my @button_params = Gtk2Ext::Info->instance->default_dialog_button_params(@button_names);

=over

=item I<Synopsis>   Gets the button params for the default button name

=item I<Params>     none

=item I<Returns>    button params (array of strings)

=back

=head2 dialog_button_params_for_buttons

 my @button_params = Gtk2Ext::Info->instance->dialog_button_params_for_buttons;

=over

=item I<Synopsis>   Gets the button params for creating a dialog by name

=item I<Params>     button name(s) (array of string(s))

=item I<Returns>    button param(s) (array of string(s))

=back

=head2 window_positions

 my @positions = Gtk2Ext::Info->instance->window_positions;

=over

=item I<Synopsis>   Gets the possible window positions

=item I<Params>     none

=item I<Returns>    window positions (array of strings)

=back

=head2 stock_ids

 my @stock_ids = Gtk2Ext::Info->instance->stock_ids;

=over

=item I<Synopsis>   Gets the Gtk2 stock id names

=item I<Params>     none

=item I<Returns>    gtk2 stock ids (array of strings)

=back

=head2 state_types

 my @state_types = Gtk2Ext::Info->instance->state_types;

=over

=item I<Synopsis>   Gets the state types for widgets

=item I<Params>     none

=item I<Returns>    gtk2 state types (array of strings)

=back

=head2 widget_layers

 my @layers = Gtk2Ext::Info->instance->widget_layers;

=over

=item I<Synopsis>   Gets the layers of a widget

=item I<Params>     none

=item I<Returns>    gtk2 widget layers

=back

=head2 color_file

 my $file_name = Gtk2Ext::Info->instance->color_file;

=over

=item I<Synopsis>   Gets the color file name for color reference

=item I<Params>     none

=item I<Returns>    file name (string)

=back

=head2 colors

 my @colors = Gtk2Ext::Info->instance->colors();

=over

=item I<Synopsis>   Gets the colors available

=item I<Params>     none    

=item I<Returns>    colors (array of hashrefs with keys name and red, green, blue integers)

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

B<Eddie Belter> <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
