package Gtk2Ext::EntryCrate;

use strict;
use warnings;

use Finfo::Std;

use Gtk2Ext::PackingFactory;
use Data::Dumper;

my %name :name(name:r);
my %label :name(label:o);
my %type :name(type:r) 
    :type(is_validation_type)
    :default('not_blank');
my %options :name(options:o)
    :type(non_empty_aryref);
my %default :name(default:o) 
    :default('');
my %multi_values :name(multi_values:o)
    :default(0);

my %label_widget :name(_label_widget:p)
    :type(object);
my %box :name(_box:p)
    :type(object);
my %entry :name(_entry:p)
    :type(object);

sub START
{
    my $self = shift; 

    $self->fatal_msg($self->name  . " requires a options params")
        and return if Finfo::Validate->type_requires_options($self->type)
            and not $self->options;

    $self->label( ucfirst($self->name) ) unless $self->label;
    
    $self->_create_box
        or ( $self->fatal_msg("Can't create entry crate") and return );

    return 1;
}

sub label_widget
{
    return shift->_label_widget;
}

sub entry
{
    return shift->_entry;
}

sub box
{
    return shift->_box;
}

sub _create_box
{
    my $self = shift;
    
    return 1 if $self->box;

    my $fac = Gtk2Ext::PackingFactory->instance;

    $self->_box
    (
        $fac->create_box(type => 'h', expand => 1,)
    )
        or return;
    
    my $table = $fac->add_table
    (
        parent => $self->box,
        col => 2,
        row => 1,
        homogen => 1,
        expand => 1,
        fill => 1,
        row_spacings => 5,
    )
        or return;

    $self->_label_widget
    (
        $fac->create_label
        (
            text => $self->label,
            h_al => 0.1,
            v_al => 0.5,
        )
    )
        or return;

    $fac->add_to_table
    (
        table => $table,
        child => $self->_label_widget,
        top => 0,
        bot => 1,
        left => 0,
        right => 1,
    )
        or return;

    $self->_entry
    ( 
        $fac->create_entry
        (
            text => $self->default,
            #h => 200,
            #v => 25,
        )
    )
        or return;

    $fac->add_to_table
    (
        table => $table,
        child => $self->entry,
        top => 0,
        bot => 1,
        left => 1,
        right => 2,
    )
        or return;

    return 1;
}

sub get_entered_value
{
    return shift->validate_entered_value
}

sub validate_entered_value
{
    my $self = shift;

    my $entered_value = $self->entry->get_text;
    my @values = ( $self->multi_values )
    ? split(/\s+/, $entered_value)
    : $entered_value;

    my @errors;
    foreach my $value (@values )
    {
        my %vp = 
        (
            attr => $self->label,
            value => $value, 
            type => $self->type,
            options => $self->options,
            err_cb => sub{ my $msg = shift; push @errors, $msg; },
        );

        Finfo::Validate->validate(%vp);
    }

    $self->error_msg( join("\n", @errors) )
        and return if @errors;
    
    return ( $self->multi_values ) ? @values : $values[0];
}

1;

=pod

=head1 Name

Gtk2Ext::EntryCrate

=head1 Synopsis

Creates an hbox with a label and entry field.  Provides automatic error checking for
entered values.

=head1 Usage

use Gtk2Ext::EntryCrate

my $ecrate = Gtk2Ext::EntryCrate->new
(
   name => req, name of the ecrate, this will be the label default
   label => opt, if different from name, displayed next to entry
   type => opt, validation type, default: 'not_blank', see Finfo::Validate for types
   options => req for some types, aryref, see Finfo::Validate
   default => opt, the default value to display
);

my $val = $ecrate->get_entered_value;

unless ( defined $val )
{
  Gtk2Ext::Dialogs->error_dialog( $ecrate->short_error_msg );
  next;
}

..more..

=head1 Methods

=head2 get_entered_value

$value(string) = $ecrate->get_entered_value;

Returns the value from the entry.  Returns undef if the validation 
failed, and sets $ecrate->error_msg ( also, short_error_msg ).

=head2 box

Gives access to the GTK::HBox or the ecrate.  Use to pack into another container,
or call methods on.

$ecrate->box->hide;

or 

$vbox->pack_start($ecrate->box, 0, 1, 10);

=head2 entry

Gives access to the Gtk2::Entry.

=head2 label

Gives access to the Gtk2::Label.

=head1 See Also

Gtk2, Finfo::Validate, Finfo::Object, Gtk2Ext directory
    
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
