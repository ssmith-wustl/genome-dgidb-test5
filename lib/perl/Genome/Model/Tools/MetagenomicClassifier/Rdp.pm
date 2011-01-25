package Genome::Model::Tools::MetagenomicClassifier::Rdp;

use strict;
use warnings;

use Genome;

use Bio::SeqIO;

class Genome::Model::Tools::MetagenomicClassifier::Rdp {
    is => 'Command',
    has => [ 
        input_file => {
            type => 'String',
            doc => "path to fasta file"
        },
    ],
    has_optional => [
        output_file => { 
            type => 'String',
            is_optional => 1, 
            doc => "Path to output file.  Defaults to STDOUT."
        },
        training_set => {
            type => 'String',
            is_optional => 1,
            default => '4',
            valid_values => [qw/ 4 6 broad /],
            doc => 'Name of training set.',
        },
        version => {
            type => 'String',
            is_optional => 1,
            default => '2.1',
            valid_values => [qw/ 2.1 2.2 /],
            doc => 'Version of rdp to run.',
        },
        format => {
            is => 'Text',
            is_optional => 1,
            valid_values => [qw/ hmp_fix_ranks hmp_all_ranks/],
            default_value => 'hmp_fix_ranks',
            doc => <<DOC,
The format of the output.
  hmp_fix_ranks => name;complemented('-' or ' ');taxon:confidence;[taxon:confidence;]
    prints only root, domain, phylum, class, order, family, genus from classification
  hmp_all_ranks => name;complemented('-' or ' ');taxon:confidence;[taxon:confidence;]
    prints ALL taxa in classification
DOC
        },
    ],
};

sub new {
    my $class = shift;
    return $class->create(@_);
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    unless ( Genome::Sys->validate_file_for_reading( $self->input_file ) ) {
        $self->delete;
        return;
    }

    return $self;
}

sub _get_classifier
{
    my $self = shift;
    my ($version, $training_set) = ($self->version, $self->training_set);
    my $classifier;

    if ($version == '2.2')
    {
        $classifier = Genome::Utility::MetagenomicClassifier::Rdp::Version2x2->new(training_set => $self->training_set);
    }
    else #2.1 or default
    {
        $classifier = Genome::Utility::MetagenomicClassifier::Rdp::Version2x1->new(training_set => $self->training_set);
    }
    
    return $classifier;
}

sub execute {
    my $self = shift;
    
    #< CLASSIFER >#
    my $classifier = $self->_get_classifier or return;
    
    #< IN >#
    my $bioseq_in = Bio::SeqIO->new(
        -format => 'fasta',
        -file => $self->input_file,
    )
        or return;

    #< OUT >#
    my $writer = Genome::Utility::MetagenomicClassifier::SequenceClassification::Writer->create(
        output => $self->output_file,
        format => $self->format,
    )
        or return;

    while ( my $seq = $bioseq_in->next_seq ) {
        my $classification = $classifier->classify($seq); # error is in sub
        if ($classification) {
            $writer->write_one($classification);
        }
    }

    return 1;
}

#< HELP >#
sub help_brief {
    "Classify sequences with rdp",
}

sub help_detail {
    return <<HELP;
   This tool will take a fasta file and output RDP classifications. An attempt will be made to classify each sequence. If it cannot be classified, an error will be displayed, and the classifier will contiue on to the next sequence.

   RDP Version Notes:
   2.1 None

   2.2 Sequences must be at least 50 bp long AND contain 42, N-free 8-mers to be classified.

HELP
}

1;

#$HeadURL$
#$Id$
