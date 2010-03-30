package Genome::Model::Build::MetagenomicComposition16s::AmpliconSet;

use strict;
use warnings;

use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';
require Genome::Utility::MetagenomicClassifier::SequenceClassification;

class Genome::Model::Build::MetagenomicComposition16s::AmpliconSet {
    is => 'UR::Object',
    has => [
        amplicon_iterator => {
            is => 'Code',
        },
        #classification_dir => { },
        #oriented_fasta_file => { },
    ],
};

#< UR >#
sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    return $self;
}

#< Amplicons >#
sub next_amplicon {
    return $_[0]->amplicon_iterator->();
}

1;

#$HeadURL$
#$Id$
