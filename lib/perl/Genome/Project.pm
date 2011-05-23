package Genome::Project;

use strict;
use warnings;
use Genome;
use Class::ISA;

class Genome::Project {
    is => 'Genome::Notable',
    id_generator => '-uuid',
    id_by => [
        id => {
            is => 'Text',
        },
    ],
    has => [
        name => {
            is => 'Text',
            doc => 'name of the project',
        },
    ],
    has_many_optional => [
        parts => {
            is => 'Genome::ProjectPart',
            reverse_as => 'project',
        },
        entities => {
            via => 'parts',
            to => 'entity',
        },
    ],
    table_name => 'GENOME_PROJECT',
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    doc => 'A project, can contain any number of objects (of any type)!',
};


sub get_parts_of_class {
    my $self = shift;
    my $desired_class = shift;
    croak $self->error_message('missing desired_class argument') unless $desired_class;

    my @parts = $self->parts;
    return unless @parts;

    my @desired_parts;
    for my $part (@parts) {
        my @classes = Class::ISA::self_and_super_path($part->entity->class);
        push @desired_parts, $part if grep { $_ eq $desired_class } @classes;
    }

    return @desired_parts;
}


1;

