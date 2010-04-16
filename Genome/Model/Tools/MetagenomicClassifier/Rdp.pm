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
            doc => "path to output file.  Defaults to STDOUT"
        },
        training_set => {
            type => 'String',
            is_optional => 1,
            default => '4',
            doc => 'name of training set (4, 6, broad)',
        },
        version => {
            type => 'String',
            is_optional => 1,
            default => '2.1',
            doc => 'Version of rdp to run.  Available versions (2.1, 2.2)',
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

    unless ( Genome::Utility::FileSystem->validate_file_for_reading( $self->input_file ) ) {
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
    my $writer = Genome::Utility::MetagenomicClassifier::Rdp::Writer->new(
        output => $self->output_file,
    )
        or return;

    while ( my $seq = $bioseq_in->next_seq ) {
        my $classification = $classifier->classify($seq);
        if ($classification) {
            $writer->write_one($classification);
        }
        else {
            warn "failed to classify ". $seq->id;
        }
    }

    return 1;
}

#< HELP >#
sub help_brief {
    "rdp classifier",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools metagenomic-classifier rdp    
EOS
}

1;

#$HeadURL$
#$Id$
