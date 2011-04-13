package Genome::Model::Tools::FastQual;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
require File::Basename;
require Genome::Utility::IO::StdinRefReader;
require Genome::Utility::IO::StdoutRefWriter;

class Genome::Model::Tools::FastQual {
    is  => 'Command',
    has => [
        input => {
            is => 'Text',
            is_many => 1,
            is_input => 1,
            doc => 'Input files, or "PIPE" if reading from another program. If multiple files are given for fastq types (sanger, illumina), one sequence will be read from each file and then handled as a set.',
            doc => 'Input files, or "PIPE" if reading from another program. If multiple files are given for fastq types (sanger, illumina), one sequence will be read from each file and then handled as a set. If multiple files are given for type phred (fasta), the first file should be the sequences, and the second file should be the qualities.',
        }, 
        type_in => {
            is  => 'Text',
            default_value => 'sanger',
            valid_values => [ valid_types() ],
            is_optional => 1,
            is_input => 1,
            doc => 'The sequence and quality type. If not given, an attempt will be made to guess the type. If the file ends in "fasta", "fna", or "fa", the type will assumed to be phred (fasta). If the file ends with "fastq", it will assumed to be sanger (fastq).',
        },
        output => {
            is => 'Text',
            is_many => 1,
            is_input => 1,
            doc => 'Output files, or "PIPE" if writing from another program. If multiple files are given for fastq types (sanger, illumina), one sequence from each set will be written to each file. If multiple files are given for type phred (fasta), the sequences will be written to the first file, and the qualities will eb written to the second file.',
        },
        _writer => {
            is_optional => 1,
        },
        type_out => {
            is  => 'Text',
            default_value => 'sanger',
            valid_values => [ valid_types() ],
            is_optional => 1,
            is_input => 1,
            doc => 'The sequence and quality type. If not given, an attempt will be made to guess the type. If the file ends in "fasta", "fna", or "fa", the type will assumed to be phred (fasta). If the file ends with "fastq", it will assumed to be sanger (fastq).',
        },
        metrics_file => {
            is => 'Text',
            is_optional => 1,
            doc => 'Output general sequence metrics to this file. Current metrics include: count, bases',
        },
        _metrics => {
            is => 'HASH',
            is_optional => 1,
        },
    ],
};

sub help_brief {
    return <<HELP
    Process fastq and fasta/quality sequences
HELP
}

sub help_detail { # empty ok
    return <<HELP 
    Process sequences. See sub-commands for a variety of functionality.

    Types Handled
    * illumina (fastq)
    * sanger (fastq)
    * phred (fasta/quality)
    
    Things This Base Command Can Do
    * collate two files into one 
    * decollate one file into two (NOT IMPLEMENTED)
    * get metrics
    * remove quality fastq headers

    Requirements
    * this base command cannot be used in a pipe

    Metrics
    * count
    * bases
    ...

    Contact ebelter\@genome.wustl.edu for help
HELP
}

# TODO 
# mv types handles doc into method
# mv metrics generated doc into method

my %supported_types = (
    sanger => { format => 'fastq', reader_subclass => 'FastqReader', writer_subclass => 'FastqWriter', },
    illumina => { format => 'fastq', reader_subclass => 'FastqReader', writer_subclass => 'FastqWriter', },
    phred => { format => 'fasta', file_exts => [qw/ fna fa /], reader_subclass => 'PhredReader', writer_subclass => 'PhredWriter', },
);

sub valid_types {
    return (qw/ sanger illumina phred/);
}

sub _reader_class {
    my $self = shift;
    return 'Genome::Model::Tools::FastQual::'.$supported_types{ $self->type_in }->{reader_subclass};
}

sub _writer_class {
    my $self = shift;
    return 'Genome::Model::Tools::FastQual::'.$supported_types{ $self->type_out }->{writer_subclass};
}

sub _enforce_type {
    my ($self, $type) = @_;

    Carp::confess('No type given to validate') if not $type;

    my @valid_types = $self->valid_types;
    if ( not grep { $type eq $_ } @valid_types ) {
        $self->error_message("Invalid type ($type). Must be ".join(', ', @valid_types));
        return;
    }

    return $type;
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    $self->_add_result_observer;  #confesses on error

    if ( not defined $self->type_out ) {
        $self->type_out( $self->type_in );
    }

    return $self;
}

sub execute {
    my $self = shift;

    my $reader = $self->_open_reader
        or return;
    if ( $reader->isa('Genome::Utility::IO::StdinRefReader') ) {
        $self->error_message('Cannot read from a PIPE! Can only collate files!');
        return;
    }
    my $writer = $self->_open_writer
        or return;
    if ( $writer->isa('Genome::Utility::IO::StdoutRefWriter') ) {
        $self->error_message('Cannot write to a PIPE! Can only collate files!');
        return;
    }

    if ( scalar($reader->files) == 1 and scalar($writer->files) == 2 ) {
        $self->error_message("Cannot decollate from one input file to two output files! (YET)");
        return;
    }

    while ( my $seqs = $reader->read ) {
        $writer->write($seqs);
    }

    return 1;
}

sub _open_reader {
    my $self = shift;

    my @input = $self->input;
    unless ( @input ) {
        Carp::confess("Input files or 'PIPE' is required.");
    }

    if ( $input[0] eq 'PIPE' ) {
        return $self->_open_stdin_reader;
    }

    my $type = $self->_enforce_type( $self->type_in );
    return if not $type;

    my $reader = eval{ $self->_reader_class->create(files => \@input); };
    if ( not  $reader ) {
        $self->error_message("Failed to create reader for input files (".join(', ', @input)."): $@");
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

    if ( not defined $reader_info->{type_in} ) {
        Carp::confess("No type in from pipe");
    }
    $self->type_in( $reader_info->{type_in} );

    if ( not defined $reader_info->{type_in} ) {
        Carp::confess("No type out from pipe");
    }

    my $type = $self->_enforce_type( $reader_info->{type_out} );
    return if not $type;
    $self->type_out($type);
    
    return $reader;
}

sub _open_writer {
    my $self = shift;

    my @output = $self->output;
    unless ( @output ) {
        Carp::confess("Output files or 'PIPE' is required.");
    }

    my $type = $self->_enforce_type( $self->type_out );
    return if not $type;

    my $writer;
    if ( $output[0] eq 'PIPE' ) {
        $writer = $self->_open_stdout_writer; # confess in sub
    }
    else {
        $writer = eval{ $self->_writer_class->create(files => \@output); };
    }

    if ( not $writer ) {
        $self->error_message("Failed to create $type writer for output files (".join(', ', @output)."): $@");
        return;
    }

    if ( $self->metrics_file ) {
        $writer->metrics( Genome::Model::Tools::FastQual::Metrics->create() );
    }

    return $self->_writer($writer);
}

sub _open_stdout_writer {
    my $self = shift;

    # open stdout ref writer
    my $writer = Genome::Utility::IO::StdoutRefWriter->create
        or Carp::confess("Can't open pipe to STDOUT");
    # write the meta info - TODO output type
    $writer->write({
            type_in => $self->type_in,
            type_out => $self->type_out,
        });

    return $writer;
}

sub _open_fastq_writer {
    my ($self, @output) = @_;

    my $writer = eval{
        $self->_writer_class->create(
            files => \@output,
        );
    };
    unless ( $writer ) {
        Carp::confess("Can't create fastq set writer for output files (".join(', ', @output)."): $@");
    }

    return $writer;
}

#< Observers >#
sub _add_result_observer { # to write metrics file
    my $self = shift;

    my $result_observer = $self->add_observer(
        aspect => 'result',
        callback => sub {
            #print Dumper(\@_);
            my ($self, $method_name, $prior_value, $new_value) = @_;
            # skip if new result is not successful
            if ( not $new_value ) {
                return 1;
            }

            # Skip if we don't have a metrics file
            my $metrics_file = $self->metrics_file;
            return 1 if not $self->metrics_file;

            # Problem if the writer or writer metric object does not exist
            if ( not $self->_writer ) {
                Carp::confess('Requested to output metrics, but the associated sequence writer does not exists');
            }
            if ( not $self->_writer->metrics ) { # very bad
                Carp::confess('Requested to output metrics, but none were found for writer:'.$self->_writer->class);
            }

            unlink $metrics_file if -e $metrics_file;
            my $fh = eval{ Genome::Sys->open_file_for_writing($metrics_file); };
            if ( not $fh ) {
                Carp::confess("Cannot open metrics file ($metrics_file) for writing: $@");
            }

            my $metrics_as_string = $self->_writer->metrics->to_string;
            $fh->print($metrics_as_string);
            $fh->close;
            return 1;
        }
    );

    if ( not defined $result_observer ) {
        Carp::confess("Cannot create result observer");
    }

    return 1;
}

1;

