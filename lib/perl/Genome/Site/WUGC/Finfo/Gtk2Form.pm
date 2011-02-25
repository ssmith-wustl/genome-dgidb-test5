package Finfo::Gtk2Form;

use strict;
use warnings;

use Finfo::Std;

use Data::Dumper;
use File::Basename;
use Gtk2::Ext::CheckButtonCrate;
use Gtk2::Ext::ComboAndEntryCrate;
use Gtk2::Ext::PackingFactory;
use Gtk2::Ext::RadioButtonCrate;

my %title :name(title:o)
    :isa(string)
    :default(__PACKAGE__->default_title);
my %classes :name(classes:r)
    :ds(aryref);
my %box :name(_box:p)
    :isa('object Gtk2::Box');
my %widgets :name(_widgets:p)
    :ds(hashref);

sub default_title
{
    return basename($0);
}

sub box
{
    return shift->_box;
}

sub START
{
    my $self = shift;

    my $factory = Gtk2::Ext::PackingFactory->instance;

    my $hbox = $factory->create_box(type => 'h');

    $self->_box($hbox);

    my %widgets;
    foreach my $class ( @{ $self->classes } )
    {
        my $frame_text = $class;
        $frame_text =~ s/::/ /g;
        my $main_box = $factory->add_box
        (
            #parent => $factory->add_frame
            #(
                parent => $hbox,
                #text => $frame_text,
                expand => 0,
                #),
        );

        my $widget_params = $self->_create_widget_params($class);
        $widgets{$class} = $self->_create_and_pack_widgets($main_box, $widget_params);
    }

    $self->_widgets(\%widgets);

    return 1;
}

sub _create_widget_params : PRIVATE
{
    my ($self, $class) = @_;

    my $widget_params = {};
    ATTR_TYPE:
    foreach my $attr_type (qw/ required optional /)
    {
        my $method = $attr_type . '_attributes';
        $self->fatal_msg("Can't get $attr_type attributes from $class")
        unless UNIVERSAL::can($class, $method);

        my @attrs = $class->$method
            or next ATTR_TYPE;

        ATTR:
        foreach my $attr ( sort @attrs )
        {
            my $clo = $class->attributes_attribute($attr, 'clo');
            $clo =~ s/\=.*$//;
            my $label = join(' ', map { ucfirst } split(/[_\-]/, $clo));
            #my $label = join(' ', map { ucfirst } split(/_/, $attr));
            my $attr_type = $class->attributes_attribute($attr, 'attr_type');
            my $attr_isa = $class->attributes_attribute($attr, 'isa');
            my ($isa) = Finfo::Validate->is_isa
            (
                attr => "isa for attribute ($attr)",
                value => $attr_isa,
                msg => 'fatal',
            );
            my $ds = $class->attributes_attribute($attr, 'ds');
            my $default = $class->attributes_attribute($attr, 'default');


            if ( $isa eq 'object' )
            {
                next ATTR;
            }
            elsif ( $attr_type eq 'r' or $isa eq 'in_list' )
            {
                push @{ $widget_params->{cne_crate} },
                {
                    name => $attr,
                    label => $label,
                    isa => $attr_isa,
                    ds => $ds,
                    default => $default,
                };
            }
            else #( $attr_type eq 'o' )
            {
                push @{ $widget_params->{cb_crate} },
                {
                    name => $attr,
                    label => $label,
                    active => $default,
                    crate_params =>
                    [
                    {
                        name => $attr,
                        label => $label,
                        isa => $attr_isa,
                        ds => $ds,
                        default => $default,
                    },
                    ]
                };
            }
        }
    }

    $self->fatal_msg
    (
        "No widgets to create for class ($class)"
    ) unless grep { exists $widget_params->{$_} } (qw/ enc_crate cb_crate /);

    return $widget_params;
}

sub _create_and_pack_widgets : PRIVATE
{
    my ($self, $box, $widget_params) = @_;

    my $factory = Gtk2::Ext::PackingFactory->instance;

    my $hbox = $factory->add_box(parent => $box, type => 'h');

    my @widgets;
    if ( $widget_params->{cne_crate} )
    {
        my $cne_crate = Gtk2::Ext::ComboAndEntryCrate->new
        (
            params => $widget_params->{cne_crate},
        );

        $factory->pack_crate
        (
            parent => $hbox,
            crate => $cne_crate,
            expand => 0,
            fill => 0,
        );

        push @widgets, $cne_crate;
    }

    if ( $widget_params->{cb_crate} )
    {
        my $cb_crate = Gtk2::Ext::CheckButtonCrate->new
        (
            button_params => $widget_params->{cb_crate},
        );

        $factory->pack_crate
        (
            parent => $hbox,
            crate => $cb_crate,
            expand => 0,
            fill => 0,
        );

        push @widgets, $cb_crate;
    }

    return \@widgets;
}

sub run
{
    my $self = shift;

    my $factory = Gtk2::Ext::PackingFactory->instance;
    my $dialog = $factory->create_dialog
    (
        title => $self->title,
        buttons => [qw/ ok cancel /],
        h => 600,
        v => 600,
    );

    $factory->add_or_pack_child
    (
        parent => $dialog->vbox,
        child => $self->_box,
    );

    RESPONSE:
    while ( 1 )
    {
        my $response = $dialog->run;
        if( $response eq 'ok' )
        {
            my ($result, $values) = $self->get_values;
            unless ( $result )
            {
                Gtk2::Ext::Dialogs->instance->error_dialog($values);
                next RESPONSE;
            }
            $dialog->destroy;
            return $values;
        }

        $dialog->destroy;
        return;
    }
}

sub get_values
{
    my $self = shift;

    $self->fatal_msg
    (
        "The get_values method returns a list: true for success AND a hashref of the values, or false for error, AND a string of the errors.  Please 'wantarray'"
    ) unless wantarray;

    my ($values, @errors);
    my $widgets = $self->_widgets;
    foreach my $class ( keys %$widgets )
    {
        foreach my $widget ( @{ $widgets->{$class} } )
        {
            my $values = $widget->get_values
                or push @errors, $widget->short_error_msg;
        }
    }

    return ( @errors ) ? (0, join("\n", @errors)) : (1, $values);
}

1;

=pod

=head1 Name

Finfo::Gtk2WidgetFactory


=head1 Synopsis

=head1 Usage

=head1 Methods

=head1 See Also

=head1 Disclaimer

Copyright (C) 2007 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

