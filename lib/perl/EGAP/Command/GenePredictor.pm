package EGAP::Command::GenePredictor;

use strict;
use warnings;

use EGAP;
use File::Temp;
use File::Basename;
use Bio::SeqIO;
use Genome::Utility::FileSystem;
use Carp 'confess';

class EGAP::Command::GenePredictor {
    is => 'EGAP::Command',
    is_abstract => 1,
    has => [
        fasta_file => {
            is => 'Path',
            is_input => 1,
            doc => 'Fasta file (possibly with multiple sequences) to be used by predictor',
        },
        raw_output_directory => {
            is => 'Path',
            is_input => 1,
            doc => 'Raw output of predictor goes into this directory',
        },
        prediction_directory => {
            is => 'Path',
            is_input => 1,
            is_output => 1,
            doc => 'Predictions are written to files in this directory',
        },
    ],
};

sub help_brief {
    return 'Abstract base class for EGAP gene prediction modules';
}

sub help_synopsis {
    return 'Abstract base class for EGAP gene prediction modules, defines a few parameters';
}

sub help_detail {
    return 'Abstract base class for EGAP gene prediction modules, defines input and output parameters';
}

sub valid_prediction_types {
    my $self = shift;
    return qw/ EGAP::RNAGene EGAP::CodingGene EGAP::Transcript EGAP::Protein EGAP::Exon /;
}

# Searches the fasta file for the named sequence and returns a Bio::Seq object representing it.
# TODO This method can be optimized so it isn't necessary to reread the entire fasta file when
# accessing sequences sequentially, which is usually the case when dealing with predictor output.
sub get_sequence_by_name {
    my ($self, $seq_name) = @_;
    my $seq_obj = Bio::SeqIO->new(
        -file => $self->fasta_file,
        -format => 'Fasta',
    );

    while (my $seq = $seq_obj->next_seq()) {
        return $seq if $seq->display_id() eq $seq_name;
    }

    return;
}

# For the given type, determine if its valid, resolve the file that needs to be locked, and lock it.
sub lock_files_for_predictions {
    my ($self, @types) = @_;
    my @locks;
    for my $type (@types) {
        unless ($self->is_valid_prediction_type($type)) {
            confess "$type is not a valid prediction type!";
        }
    
        my $ds = $type->__meta__->data_source;
        my $file_resolver = $ds->can('file_resolver');
        my $file = $file_resolver->($self->prediction_directory);

        my $resource_lock = "/gsc/var/lock/EGAP/$file";
        my $lock = Genome::Utility::FileSystem->lock_resource(
            resource_lock => $resource_lock,
            block_sleep => 60,
            max_try => 10,
        );
        confess "Could not get lock on $file for type $type!" unless $lock;
        push @locks, $lock;
    }
    return @locks;
}

# Release locks for prediction files
sub release_prediction_locks {
    my ($self, @locks) = @_;
    for my $lock (@locks) {
        Genome::Utility::FileSystem->unlock_resource(
            resource_lock => $lock,
        );
    }
    return 1;
}

sub is_valid_prediction_type {
    my ($self, $type) = @_;
    for my $valid_type ($self->valid_prediction_types) {
        return 1 if $type eq $valid_type;
    }
    return 0;
}
1;
