package Genome::Model::Tools::FastQual;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
use File::Basename;
#require Genome::Model::Tools::FastQual::FastaQualReader;
#require Genome::Model::Tools::FastQual::FastaQualWriter;
require Genome::Model::Tools::FastQual::FastqSetReader;
require Genome::Model::Tools::FastQual::FastqSetWriter;
require Genome::Utility::IO::StdinRefReader;
require Genome::Utility::IO::StdoutRefWriter;

class Genome::Model::Tools::FastQual {
    is  => 'Command',
    is_abstract => 1,
    has => [
        input_files => {
            is => 'Text',
            is_many => 1,
            is_input => 1,
            doc => 'Input files, or "PIPE" if reading from another program. If multiple files are given for fastq types (sanger, illumina), one sequence will be read from each file and then handled as a set.',
            # TODO includes fasta:
            # doc => 'Input files, or "PIPE" if reading from another program. If multiple files are given for fastq types (sanger, illumina), one sequence will be read from each file and then handled as a set. If multiple files are given for type phred (fasta), the first file should be the sequences, and the second file should be the qualities.',
        }, 
        output_files => {
            is => 'Text',
            is_many => 1,
            is_input => 1,
            doc => 'Output files, or "PIPE" if writing to another program. If multiple files are given for fastq types (sanger, illumina), one sequence from each set will be written to each file.',
            # TODO includes fasta: 
            # doc => 'Output files, or "PIPE" if writing from another program. If multiple files are given for fastq types (sanger, illumina), one sequence from each set will be written to each file. If multiple files are given for type phred (fasta), the sequences will be written to the first file, and the qualities will eb written to the second file.',
        },
        type => {
            is  => 'Text',
            default_value => 'sanger',
            is_optional => 1,
            is_input => 1,
            doc => 'The sequence and quality type. Valid values are: '.join(' ', __PACKAGE__->valid_types).'.',
            # TODO includes phred (fasta):
            # doc => 'The sequence and quality type. If not given, an attempt will be made to guess the type. If the file ends in "fasta", "fna", or "fa", the type will assumed to be phred (fasta). If the file ends with "fastq", it will assumed to be sanger (fastq).',
        },
        # TODO add output type
    ],
};

#< Helps >#
sub help_brief {
    return <<HELP
    Process fastq and fasta/quality sequences
HELP
}

sub help_detail { # empty ok
    return <<HELP 
HELP
}
#<>#

#< Types and Formats >#
my %supported_types = (
    sanger => { format => 'fastq', },
    illumina => { format => 'fastq', },
    phred => { format => 'fasta', file_exts => [qw/ fna fa /], },
);
sub valid_types {
    return keys %supported_types;
}

sub validate_type {
    my ($self, $type) = @_;

    unless ( defined $type ) {
        Carp::confess("Cannot validate type. It is not defined");
    }

    my @valid_types = $self->valid_types;
    unless ( grep { $type eq $_ } @valid_types ) {
        Carp::confess("Cannot validate type ($type). It must be: ".join(', ', @valid_types));
    }

    return $type;
}

sub format_for_type {
    my ($self, $type) = @_;

    unless ( defined $type ) {
        Carp::confess("Cannot get format for type. It is not defined");
    }

    unless ( exists $supported_types{$type} ) {
        Carp::confess("Cannot get format for type ($type). It must be: ".join(', ', $self->valid_types));
    }

    return $supported_types{$type}->{format};
}

sub _enforce_type {
    my $self = shift;

    my $type = $self->type;
    unless ( defined $type ) {
        Carp::confess("No type set.");
    }
    my @valid_types = $self->valid_types;
    unless ( grep { $type eq $_ } @valid_types ) {
        Carp::confess("Invalid type ($type). Must be ".join(', ', @valid_types));
    }

    return $type;
}
#<>#

#< Reader Writer >#
sub _open_reader {
    my $self = shift;

    my @input_files = $self->input_files;
    unless ( @input_files ) {
        Carp::confess("Input files or 'PIPE' is required.");
    }

    if ( $input_files[0] eq 'PIPE' ) {
        return $self->_open_stdin_reader;
    }

    my $type = $self->_enforce_type
        or return;
    
    my $reader;
    eval{
        $reader = Genome::Model::Tools::FastQual::FastqSetReader->create(
            files => \@input_files,
        );
    };
    unless ( $reader ) {
        $self->error_message("Can't create fastq reader for input files (".join(', ', @input_files)."): $@");
        return;
    }

    return $reader;
}

sub _open_stdin_reader {
    my $self = shift;

    # open the stdin reader
    my $reader = Genome::Utility::IO::StdinRefReader->create()
        or Carp::confess("Can't open pipe to STDIN");

    # get the reader meta, set alarm b/c it will hang if nothing is there
    my $reader_info;
    eval {
        local $SIG{ALRM} = sub{ die; };
        alarm 5;
        $reader_info = $reader->read;
        alarm 0;
    };
    unless ( $reader_info ) {
        Carp::confess("No pipe meta info. Are you sure you wanted to read from a pipe?");
    }

    my $type = $reader_info->{type};
    unless ( $type ) {
        Carp::confess("No type from pipe");
    }
    $self->type( $reader_info->{type} );
    $self->_enforce_type;
    
    return $reader;
}

sub _open_writer {
    my $self = shift;

    my @output_files = $self->output_files;
    unless ( @output_files ) {
        Carp::confess("Output files or 'PIPE' is required.");
    }

    if ( $output_files[0] eq 'PIPE' ) {
        return $self->_open_stdout_writer;
    }

    my $type = $self->_enforce_type
        or return;
    
    my $writer;
    eval{
        $writer = Genome::Model::Tools::FastQual::FastqSetWriter->create(
            files => \@output_files,
        );
    };
    unless ( $writer ) {
        $self->error_message("Can't create fastq writer for output files (".join(', ', @output_files)."): $@");
        return;
    }

    return $writer;
}

sub _open_stdout_writer {
    my $self = shift;

    # open stdout ref writer
    my $writer = Genome::Utility::IO::StdoutRefWriter->create
        or Carp::confess("Can't open pipe to STDOUT");
    # write the meta info - TODO output type
    $writer->write({ type => $self->type });

    return $writer;
}

1;

#$HeadURL$
#$Id$
