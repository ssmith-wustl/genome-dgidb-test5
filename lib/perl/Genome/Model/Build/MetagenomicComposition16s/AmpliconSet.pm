package Genome::Model::Build::MetagenomicComposition16s::AmpliconSet;

use strict;
use warnings;

use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';

class Genome::Model::Build::MetagenomicComposition16s::AmpliconSet {
    is => 'UR::Object',
    has => [
        name => {
            is => 'Text',
        },
        amplicon_iterator => {
            is => 'Code',
        },
        classification_dir => { 
            is => 'Text',
        },
        classification_file => { 
            is => 'Text',
        },
        processed_fasta_file => { 
            is => 'Text',
        },
        processed_qual_file => { 
            is_optional => 1,
            is => 'Text',
        },
        oriented_fasta_file => { 
            is => 'Text',
        },
        oriented_qual_file => { 
            is_optional => 1,
            is => 'Text',
        },
    ],
};

#< UR >#
sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    for my $property (qw/ name amplicon_iterator classification_dir classification_file processed_fasta_file oriented_fasta_file /) {
        unless ( defined $self->$property ) {
            $self->error_message("Required property ($property) not defined.");
            $self->delete;
            return;
        }
    }

    return $self;
}

#< Amplicons >#
sub next_amplicon {
    return $_[0]->amplicon_iterator->();
}

1;

#$HeadURL$
#$Id$
