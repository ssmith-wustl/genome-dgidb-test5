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
            is_optional => 1, ###
            doc => "path to output file.  Defaults to STDOUT"
        },
        training_set => {
            type => 'String',
            doc => 'name of training set (broad)',
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

sub execute {
    my $self = shift;
    
    #< CLASSIFER >#
    require Genome::Utility::MetagenomicClassifier::Rdp;
    my $classifier = Genome::Utility::MetagenomicClassifier::Rdp->new(
        training_set => $self->training_set,
    )
        or return;
    
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
