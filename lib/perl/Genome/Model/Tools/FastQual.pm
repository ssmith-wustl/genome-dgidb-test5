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
            is_optional => 1,
            doc => 'Input files, "-" to read from STDIN or undefined if piping between fast-qual commands. If multiple files are given for fastq types (sanger, illumina), one sequence will be read from each file and then handled as a set. If multiple files are given for type phred (fasta), the first file should be the sequences, and the optional second file should be the qualities. Do not use this option when piping between fast-qual commands.',
        }, 
        input_to_string => {
            calculate_from => [qw/ input /],
            calculate => q| 
                return 'PIPE' if not defined $input;
                return 'STDin' if $input->[0] eq '-';
                return join(',', @$input);
            |,
        },
        type_in => {
            is  => 'Text',
            valid_values => [ valid_types() ],
            is_optional => 1,
            doc => 'The sequence and quality type for the input. Optional for files, and if not given, will be based on the extension of the first file (.fastq => sanger | .fasta .fna .fa => phred). Required for reading from STDIN. Do not use this option when piping between fast-qual commands.',
        },
        metrics_file_out => {
            is => 'Text',
            is_optional => 1,
            doc => 'Output sequence metrics for the output to this file. Current metrics include: count, bases',
        },
        output => {
            is => 'Text',
            is_many => 1,
            is_optional => 1,
            doc => 'Output files, "-" to write to STDOUT or undefined if piping between fast-qual commands.  Optional for files, and if not given, will be based on the extension of the first file (.fastq => sanger  .fasta .fna .fa => phred). Do not use this option when piping between fast-qual commands. ',
        },
        output_to_string => {
            calculate_from => [qw/ output /],
            calculate => q| 
                return 'PIPE' if not defined $output;
                return 'STDOUT' if $output->[0] eq '-';
                return join(',', @$output);
            |,
        },
        type_out => {
            is  => 'Text',
            valid_values => [ valid_types() ],
            is_optional => 1,
            doc => 'The sequence and quality type for the output. Optional for files, and if not given, will be based on the extension of the first file (.fastq => sanger | .fasta .fna .fa => phred). Defaults to sanger (fastq) for writing to STDOUT. Do not use this option when piping between fast-qual commands.',
        },
        _reader => { is_optional => 1, },
        _writer => { is_optional => 1, },
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

my %supported_types = (
    sanger => { format => 'fastq', reader_subclass => 'FastqReader', writer_subclass => 'FastqWriter', },
    illumina => { format => 'fastq', reader_subclass => 'FastqReader', writer_subclass => 'FastqWriter', },
    phred => { format => 'fasta', reader_subclass => 'PhredReader', writer_subclass => 'PhredWriter', },
);

sub valid_types {
    return (qw/ sanger illumina phred/);
}

sub _resolve_type_for_file {
    my ($self, $file) = @_;

    Carp::Confess('No file to resolve type') if not $file;

    my ($ext) = $file =~ /\.(\w+)$/;
    if ( not $ext ) {
        $self->error_message('Failed to get extension for file: '.$file);
        return;
    }

    my %file_exts_and_formats = (
        fastq => 'sanger',
        fasta => 'phred',
        fna => 'phred',
        fa => 'phred',
    );
    return $file_exts_and_formats{$ext} if $file_exts_and_formats{$ext};
    $self->error_message('Failed to resolve type for file: '.$file);
    return;
}

sub _reader_class {
    my $self = shift;
    if ( not $supported_types{ $self->type_in }->{reader_subclass} ) {
        $self->error_message('Invalid type in: '.$self->type_in);
        return;
    }
    return 'Genome::Model::Tools::FastQual::'.$supported_types{ $self->type_in }->{reader_subclass};
}

sub _writer_class {
    my $self = shift;
    if ( not $supported_types{ $self->type_out }->{writer_subclass} ) {
        $self->error_message('Invalid type out: '.$self->type_out);
        return;
    }
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

    my $self = $class->SUPER::create(@_);
    return if not $self;

    my @input = $self->input;
    my $type_in = $self->type_in;
    if ( @input ) {
        if ( $input[0] eq '-' ) { # STDIN
            if ( @input > 1 ) { # Cannot have morethan one STDIN
                $self->error_message('Multiple STDIN inputs given: '.$self->input_to_string);
                return;
            }
            if ( not $type_in ) {
                $self->error_message('Input from STDIN, but no type in given');
                return;
            }
        }
        else { # FILES
            if ( not $type_in ) {
                $type_in = $self->_resolve_type_for_file($input[0]);
                return if not $type_in;
                $self->type_in($type_in);
            }
        }
    }
    elsif ( $type_in ) { # PIPE sets it's own type in
        $self->error_message('Do not set type in when piping between fast-qual commands.');
        return;
    }

    my @output = $self->output;
    my $type_out = $self->type_out;
    if ( @output ) {
        if ( $output[0] eq '-' ) { # STDOUT
            if ( @output > 1 ) { # Cannot have morethan one STDOUT
                $self->error_message('Multiple STDOUT outputs given: '.$self->output_to_string);
                return;
            }
            if ( not $type_out ) {
                $self->type_out('sanger');
            }
        }
        else { # FILES
            if ( not $type_out ) {
                $type_out = $self->_resolve_type_for_file($output[0]);
                return if not $type_out;
                $self->type_out($type_out);
            }
        }
    }
    elsif ( $type_out ) { # PIPE sets it's own type out
        $self->error_message('Do not set type out when piping between fast-qual commands.');
        return;
    }

    $self->_add_result_observer;  #confesses on error

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
    my $type_in = $self->type_in;
    my $reader;
    if ( not @input and not $type_in ) { # PIPE
        $reader = $self->_open_stdin_reader;
    }
    else { # STDIN/files
        my $reader_class = $self->_reader_class;
        return if not $reader_class;
        $reader = eval{ $reader_class->create(files => \@input); };
    }

    if ( not  $reader ) {
        $self->error_message("Failed to create reader for input: ".$self->input_to_string);
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

    my @output = $self->output;
    if ( @output ) { # STDOUT or FILES
        my $type = $self->_enforce_type( $reader_info->{type_out} );
        return if not $type;
        $self->type_out($type);
    }
    else { # PIPE
        $self->type_out( $self->type_in );
    }

    return $reader;
}

sub _open_writer {
    my $self = shift;

    my @output = $self->output;
    my $writer;
    if ( not @output ) { # PIPE - type out is always defined here
        $writer = $self->_open_stdout_writer;
    }
    else { # STDOUT/FILES
        my $writer_class = $self->_writer_class;
        return if not $writer_class;
        $writer = eval{ $writer_class->create(files => \@output); };
    }

    if ( not $writer ) {
        $self->error_message("Failed to create writer for output: ".$self->output_to_string);
        return;
    }

    if ( $self->metrics_file_out ) {
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
            my $metrics_file = $self->metrics_file_out;
            return 1 if not $self->metrics_file_out;

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

