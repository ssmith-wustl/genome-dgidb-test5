package Genome::Model::Build::MetagenomicComposition16s::Amplicon;

use strict;
use warnings;

use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';
require Genome::Utility::MetagenomicClassifier::SequenceClassification;
require Storable;

class Genome::Model::Build::MetagenomicComposition16s::Amplicon {
    is => 'UR::Object',
    has => [
        name => {
            is => 'Text',
            doc => 'Name of amplicon.',
        },
        reads => {
            is => 'ARRAY',
            doc => 'Reads for the amplicon.',
        },
        classification_file => {
            is => 'Text',
            doc => 'Classification storable file.',
        },
    ],
    has_optional => [
        reads_processed => {
            is => 'ARRAY',
            default_value => [],
            doc => 'Reads that were porcessed and incorporated into this amplicon\'s sequence.',
        },
        seq => {
            is => 'Hash',
            doc => 'Processed unoriented sequence.',
        },
    ],
};

#< UR >#
sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    for my $attr (qw/ name reads classification_file /) {
        next if $self->$attr;
        $self->error_message("Attribute ($attr) is required to create");
        $self->delete;
        return;
    }

    return $self;
}

#< Oriented Seq >#
sub oriented_seq {
    my $self = shift;

    my $seq = $self->seq;
    return if not $seq;

    my $classification = $self->classification;
    return if not $classification;

    if ( $classification->is_complemented ) {
        $seq->{seq} = reverse $seq->{seq};
        $seq->{seq} =~ tr/ATGCatgc/TACGtacg/;
    }

    return $seq;
}

#< Read Counts >#
sub reads_count {
    return scalar(@{$_[0]->reads});
}

sub reads_processed_count {
    return scalar(@{$_[0]->reads_processed});
}

#< Classification >#
sub classification {
    my ($self, $classification) = @_;

    if ( $classification ) { #save
        my $classification_file = $self->classification_file;
        unlink $classification_file if -e $classification_file;
        eval {
            Storable::store($classification, $classification_file);
        };
        if ( $@ ) {
            $self->error_message("Can't store amplicon's (".$self->name.") classification to file ($classification_file)");
            return;
        }

        $self->{classification} = $classification;
        return $self->{classification};
    }

    return $self->{classification} if $self->{classification};

    # load
    my $classification_file = $self->classification_file;
    return unless -s $classification_file; # ok
    
    eval {
        $classification = Storable::retrieve($classification_file);
    };
    
    unless ( $classification ) {
        $self->error_message("Can't retrieve amplicon's (".$self->name.") classification from file ($classification_file) for ".$self->description);
        die;
    }

    $self->{classification} = $classification;
    return $self->{classification};
}

1;

