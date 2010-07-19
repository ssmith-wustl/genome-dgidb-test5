package Genome::Model::Tools::FastQual;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
use File::Basename;
require Genome::Model::Tools::Fastq::SetReader;
require Genome::Model::Tools::Fastq::SetWriter;
#require Genome::Utility::IO::StdinRefReader;
#require Genome::Utility::IO::StdoutRefWriter;

class Genome::Model::Tools::FastQual {
    is  => 'Command',
    has_input => [
        input_files => {
            is  => 'Text',
            is_many => 1,
            is_optional => 1,
            doc => 'Input files. If multiple files are given, they will be handled as a set and evaluated as set.',
        }, 
        output_files => {
            is  => 'Text',
            is_many => 1,
            is_optional => 1,
            doc => 'Output files. If multiple files are given, each sequence of the set will be written to the file.',
        },
        type => {
            is  => 'Text',
            valid_values  => [qw/ sanger illumina fasta /],
            default_value => 'sanger',
            is_optional => 1,
            doc => 'The fastq quality type.',
        },
    ],
};

sub help_synopsis {
    return <<HELP
HELP
}

sub help_detail {
    return <<HELP 
HELP
}

sub _open_reader {
    my $self = shift;

    my @input_files = $self->input_files;
    unless ( @input_files ) {
        Carp::confess("Output fastq files are required.");
        #return Genome::Utility::IO::StdinRefReader->create;
    }

    my $reader;
    eval{
        $reader = Genome::Model::Tools::Fastq::SetReader->create(
            fastq_files => \@input_files,
        );
    };
    unless ( $reader ) {
        $self->error_message("Can't create fastq reader for input files (".join(', ', @input_files)."): $@");
        return;
    }

    return $reader;
}

sub _open_writer {
    my $self = shift;

    my @output_files = $self->output_files;
    unless ( @output_files ) {
        Carp::confess("Output fastq files are required.");
        #return Genome::Utility::IO::StdoutRefWriter->create();
    }

    my $writer;
    eval{
        $writer = Genome::Model::Tools::Fastq::SetWriter->create(
            fastq_files => \@output_files,
        );
    };
    unless ( $writer ) {
        $self->error_message("Can't create fastq writer for output files (".join(', ', @output_files)."): $@");
        return;
    }

    return $writer;
}

1;

#$HeadURL$
#$Id$
