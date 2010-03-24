
package Genome::Model::Tools::Galaxy::GenerateToolXml;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Galaxy::GenerateToolXml {
    is => 'Command',
    has => [
        class_name => {
            is => 'String',
            doc => 'Input class name'
        }
    ]
};

sub execute {
    my $self = shift;

    # Old-style definations call a function after setting up the class
    {
        eval "use " . $self->class_name;
        if ($@) {
            die $@;
        }
    }

    my $self = $class->SUPER::create(@_);
    my $command = $self->command_class_name;


    my $class_meta = $command->get_class_object;
    die 'invalid command class' unless $class_meta;

    my @property_meta = $class_meta->all_property_metas();

    foreach my $type (qw/input output/) {
        my $my_method = $type . '_properties';
        unless ($self->$my_method) {
            my @props = map {
                $_->property_name
            } grep {
                defined $_->{'is_' . $type} && $_->{'is_' . $type}
            } @property_meta;

            if ($type eq 'input') {
                my @opt_input = map {
                    $_->property_name
                } grep {
                    $_->is_optional &&
                    defined $_->{'is_input'} && $_->{'is_input'}
                } @property_meta;

                $self->optional_input_properties(\@opt_input);
            }

            $self->$my_method(\@props);
        }
    }

}

