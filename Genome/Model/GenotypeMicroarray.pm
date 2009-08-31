package Genome::Model::GenotypeMicroarray;

use strict;
use warnings;

use Genome;
use File::Basename;
use Sort::Naturally;
use IO::File;

class Genome::Model::GenotypeMicroarray{
    #is => 'Genome::Model::ImportedVariants',
    is => 'Genome::Model',
    has => [
        #file => { }; # where to get this? misc_attributes?
        input_format    => { via => 'processing_profile' },
        instrument_type => { via => 'processing_profile' },
    ],
};


sub create
{
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return unless $self;

    return $self;
}

# Hack for now to get genome-model list models to not break
sub reference_sequence_name {
    return 'N/A';
}

1;

