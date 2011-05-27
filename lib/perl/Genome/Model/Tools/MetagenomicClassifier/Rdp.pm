package Genome::Model::Tools::MetagenomicClassifier::Rdp;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::MetagenomicClassifier::Rdp {
    is => 'Command',
    has => [ 
        input_file => {
            type => 'String',
            doc => "Path to fasta file"
        },
        output_file => { 
            type => 'String',
            doc => "Path to output file."
        },
        training_set => {
            type => 'String',
            valid_values => [qw/ 4 6 broad /],
            doc => 'Name of training set.',
        },
        version => {
            type => 'String',
            valid_values => [qw/ 2x1 2x2 /],
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
        metrics => { 
            is => 'Boolean',
            is_optional => 1, 
            doc => "Write metrics to file. File name is classification file w/ '.metrics' extension",
        },
    ],
};

sub execute {
    my $self = shift;
    
    #< CLASSIFER >#
    my $classifier_class = 'Genome::Model::Tools::MetagenomicClassifier::Rdp::Version'.$self->version;
    my $classifier = $classifier_class->create(
        training_set => $self->training_set,
    );
    return if not $classifier;

    #< IN >#
    my $reader = eval {
        Genome::Model::Tools::FastQual::PhredReader->create(
            files => [ $self->input_file ],
        );
    };
    return if not $reader;

    #< OUT >#
    my $writer = Genome::Model::Tools::MetagenomicClassifier::ClassificationWriter->create(
        file => $self->output_file,
        format => $self->format,
    );
    return if not $writer;

    my %metrics;
    @metrics{qw/ total error success /} = (qw/ 0 0 0 /);
    while ( my $seqs = $reader->read ) {
        $metrics{total}++;
        my $classification = $classifier->classify($seqs->[0]);
        if ( not $classification ) {
            $metrics{error}++;
            next;
        }
        $writer->write($classification); # TODO check?
        $metrics{success}++;
    }

    if ( $self->metrics ) {
        $self->_write_metrics(\%metrics);
    }

    return 1;
}

sub _write_metrics {
    my ($self, $metrics) = @_;

    my $metrics_file = $self->output_file.'.metrics';
    unlink $metrics_file if -e $metrics_file;

    my $metrics_fh = eval{ Genome::Sys->open_file_for_writing($metrics_file); };
    if ( not $metrics_fh ) {
        $self->error_message("Failed to open metrics file ($metrics_file) for writing: $@");
        return;
    }

    for my $metric ( keys %$metrics ) {
        $metrics_fh->print($metric.'='.$metrics->{$metric}."\n");
    }

    $metrics_fh->close;

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

