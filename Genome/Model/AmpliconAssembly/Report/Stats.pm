package Genome::Model::AmpliconAssembly::Report::Stats;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::AmpliconAssembly::Report::Stats {
    # Double inheritance...boo!
    is => [qw/ Genome::Model::Report Genome::AmpliconAssembly::Report::Stats /],
    has => [
    # Overwirte these in G:AA:R:Stats by making them calculated
    description => {
        calculate_from => [qw/ model_name build_id /],
        calculate => q|
        return sprintf(
        'Assembly Stats for Amplicon Assembly (Name <%s> Build Id <%s>)',
        $self->model_name,
        $self->build_id,

        );
        |,
    },
    amplicon_assemblies => {
        calculate => q| return [ $self->build->amplicon_assembly ]; |,
    },
    assembly_size => {
        calculate => q| return $self->model->assembly_size; |,
    },
    ],
};

1;

#$HeadURL$
#$Id$
