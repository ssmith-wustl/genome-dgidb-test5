package Genome::Model::Tools::Sx;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
require File::Basename;
require Genome::Utility::IO::StdinRefReader;
require Genome::Utility::IO::StdoutRefWriter;

class Genome::Model::Tools::Sx {
    is  => 'Command',
    has => [
        input => {
            is => 'Text',
            is_many => 1,
            is_optional => 1,
            doc => "Input files, '-' to read from STDIN or undefined if piping between fast-qual commands.\nSANGER/ILLLUMINA: If one input is given, one sequence will be read at a time. Use 'paired_input' to read two sequences from a single input. If multiple inputs are given,  one sequence will be read from each and then handled as a set.\nPHRED: Give fasta first, then optional quality input.\nDo not use this option when piping from fast-qual commands.",
        }, 
        _input_to_string => {
            calculate => q| 
                my @input = $self->input;
                return 'PIPE' if not @input;
                return 'STDin' if $input[0] eq '-';
                return join(',', @input);
            |,
        },
        type_in => {
            is  => 'Text',
            valid_values => [ valid_type_ins() ],
            is_optional => 1,
            doc => 'The sequence and quality type for the input. Optional for files, and if not given, will be based on the extension of the first file (.fastq => sanger | .fasta .fna .fa => phred). Required for reading from STDIN. Do not use this option when piping from fast-qual commands.',
        },
        paired_input => {
            is => 'Boolean',
            is_optional => 1,
            doc => "FASTQ: If giving one input, read two sequences at a time. If two inputs are given, this will set to true. A sequence will be read from each input.\nPHRED: NA.\nDo not use this option when piping from fast-qual commands.",
        },
        output => {
            is => 'Text',
            is_many => 1,
            is_optional => 1,
            doc => "Output files, '-' to write to STDOUT or undefined if piping between fast-qual commands.\nSANGER/ILLLUMINA: If one output is given, sequences will be written to it. To write only pairs, use 'paired_output'. If 2 outputs are given, a sequence will be written to each, and singletons will be disgarded. To write pairs to one output and singletons to the other, use 'paired_output'. If three outputs are given, the first of a pair will be written to the first and and the second of a pair to the second. Singletons will be written to the third.\nPHRED: Give fasta first, then optional quality input.\nDo not use this option when piping to fast-qual commands.",
        },
        _output_to_string => {
            calculate => q| 
                my @output = $self->output;
                return 'PIPE' if not @output;
                return 'STDOUT' if $output[0] eq '-';
                return join(',', @output);
            |,
        },
        type_out => {
            is  => 'Text',
            valid_values => [ valid_type_outs() ],
            is_optional => 1,
            doc => 'The sequence and quality type for the output. Optional for files, and if not given, will be based on the extension of the first file (.fastq => sanger | .fasta .fna .fa => phred). Defaults to sanger (fastq) for writing to STDOUT. Do not use this option when piping to fast-qual commands.',
        },
        paired_output => {
            is => 'Boolean',
            is_optional => 1,
            doc => "FASTQ: Write pairs to the same output file. If giving one output, write pairs to it, discarding singletons. If given two outputs, write pairs to the first, singletons to the second. Do not use for three outputs.\nPHRED: NA\nDo not use this option when piping to fast-qual commands.",
        },
        metrics_file_out => {
            is => 'Text',
            is_optional => 1,
            doc => 'Output sequence metrics for the output to this file. Current metrics include: count, bases',
        },
        _reader => { is_optional => 1, },
        _writer => { is_optional => 1, },
    ],
};

sub help_brief {
    return 'Transform sequences';
}

sub help_synopsis {
    return <<HELP;
    Transform sequences. See sub-commands for a variety of functionality.

    Types Handled
    * sanger (fastq)
    * phred (fasta/quality)
    
    Things This Base Command Can Do
    * collate two inputs into one (sanger, illumina only)
    * decollate one input into two (sanger, illumina only)
    * convert type
    * remove quality fastq headers
    
    Things This Base Command Can Not Do
    * be used in a pipe

    Metrics
    * count
    * bases

    Contact ebelter\@genome.wustl.edu for help
HELP
}

sub help_detail {
    return <<HELP;

    * Convert type
    ** illumina fastq to sanger
    gmt fast-qual --input illumina.fastq --type-in illumina --output sanger.fastq
    ** sanger fastq to phred fasta
    gmt fast-qual --input file.fastq --output file.fasta --type-out phred
    ** sanger fastq to phred fasta w/ quals
    gmt fast-qual --input file.fastq --output file.fasta file.qual --type-out phred

    * Collate
    ** from paired fastqs (type-in resolved to sanger, type-out defaults to sanger)
    gmt fast-qual --input fwd.fastq rev.fastq --output collated.fastq --paired-output
    ** to paired STDOUT (type-in resolved to sanger, type-out defaults to sanger)
    gmt fast-qual --input fwd.fastq rev.fastq --output - --paired-output

    * Decollate
    ** from illumina to paired fastqs (type-in resolved to sanger, type-out defaults to sanger)
    gmt fast-qual --input collated.fastq --paired-input --output fwd.fastq rev.fastq
    ** from paired illumina STDIN (type-in req'd = illumina, type-out defaults to sanger)
    gmt fast-qual --input - --paired-input --type-in illumnia --output fwd.fastq rev.fastq

    * Use in PIPE (cmd represents a fast-qual sub command)
    ** from singleton fastq file
    gmt fast-qual cmd1 --cmd1-options --input sanger.fastq | gmt fast-qual cmd2 --cmd2-options --output sanger.fastq
    ** from paired STDIN to paired fastq and singleton (assuming the sub commands filter singletons)
    cat collated_fastq | gmt fast-qual cmd1 --cmd1-options --input - --paired-input | gmt fast-qual cmd2 --cmd2-options --output pairs.fastq

HELP
}

my %supported_types = (
    sanger => { format => 'fastq', reader_subclass => 'FastqReader', writer_subclass => 'FastqWriter', },
    illumina => { format => 'fastq', reader_subclass => 'IlluminaFastqReader', writer_subclass => 'IlluminaFastqWriter', },
    phred => { format => 'fasta', reader_subclass => 'PhredReader', writer_subclass => 'PhredWriter', },
    bed => { format => 'bed', writer_subclass => 'BedWriter', },
);
sub valid_type_ins {
    return (qw/ sanger illumina phred /);
}

sub valid_type_outs {
    return (qw/ sanger illumina phred bed /);
}

sub _resolve_type_for_file {
    my ($self, $file) = @_;

    Carp::Confess('No file to resolve type') if not $file;

    $self->status_message('Resolving type for file: '.$file);

    my ($ext) = $file =~ /\.(\w+)$/;
    if ( not $ext ) {
        $self->error_message('Failed to get extension for file: '.$file);
        return;
    }

    my %file_exts_and_formats = (
        bed => 'bed',
        fastq => 'sanger',
        fasta => 'phred',
        fna => 'phred',
        fa => 'phred',
    );
    if ( $file_exts_and_formats{$ext} ) {
        $self->status_message('Type: '.$file_exts_and_formats{$ext});
        return $file_exts_and_formats{$ext};
    }
    $self->error_message('Failed to resolve type for file: '.$file);
    return;
}

sub _reader_class {
    my $self = shift;
    if ( not $self->input ) {
        return 'Genome::Utility::IO::StdinRefReader';
    }
    if ( not $supported_types{ $self->type_in }->{reader_subclass} ) {
        $self->error_message('Invalid type in: '.$self->type_in);
        return;
    }
    return 'Genome::Model::Tools::Sx::'.$supported_types{ $self->type_in }->{reader_subclass};
}

sub _writer_class {
    my $self = shift;
    if ( not $self->output ) {
        return 'Genome::Utility::IO::StdoutRefWriter';
    }
    if ( not $supported_types{ $self->type_out }->{writer_subclass} ) {
        $self->error_message('Invalid type out: '.$self->type_out);
        return;
    }
    return 'Genome::Model::Tools::Sx::'.$supported_types{ $self->type_out }->{writer_subclass};
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return if not $self;

    my @input = $self->input;
    my $type_in = $self->type_in;
    if ( @input ) {
        if ( @input > 2 ) {
            $self->error_message('Can only handle 1 or 2 inputs');
            return;
        }
        if ( $input[0] eq '-' ) { # STDIN
            if ( @input > 1 ) { # Cannot have morethan one STDIN
                $self->error_message('Multiple STDIN inputs given: '.$self->_input_to_string);
                return;
            }
            if ( not $type_in ) {
                $self->error_message('Input from STDIN, but no type in given');
                return;
            }
        }
        else { # FILES
            if ( defined $self->paired_input and @input > 2 ) {
                $self->error_message('Cannot use paired_input with more than 2 inputs');
                return;
            }
            if ( not $type_in ) {
                $type_in = $self->_resolve_type_for_file($input[0]);
                return if not $type_in;
                $self->type_in($type_in);
            }
        }
    }
    else {
        if ( $type_in ) { # PIPE is always sanger
            $self->error_message('Do not set type in when piping between fast-qual commands');
            return;
        }
        if ( defined $self->paired_input ) {
            $self->error_message('Do not set paired_input when piping between fast-qual commands');
            return;
        }
    }

    my @output = $self->output;
    my $type_out = $self->type_out;
    if ( @output ) {
        if ( $output[0] eq '-' ) { # STDOUT
            if ( @output > 1 ) { # Cannot have more than one STDOUT
                $self->error_message('Multiple STDOUT outputs given: '.$self->_output_to_string);
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
    else {
        if ( $type_out ) { # PIPE is always sanger
            $self->error_message('Do not set type out when piping between fast-qual commands.');
            return;
        }
        if ( $self->paired_output ) {
            $self->error_message('Do not set paired_output when piping between fast-qual commands.');
            return;
        }
    }

    $self->_add_result_observer;  #confesses on error

    return $self;
}

sub execute {
    my $self = shift;

    if ( $self->input == $self->output and $self->type_in eq $self->type_out and !defined $self->metrics_file_out ) {
        $self->error_message("Cannot read and write the same number of input/outputs and with the same type in/out when metrics_file_out is not defined");
        return;
    }

    my ($reader, $writer) = $self->_open_reader_and_writer
        or return;
    if ( $reader->isa('Genome::Utility::IO::StdinRefReader') ) {
        $self->error_message('Cannot read from a PIPE!');
        return;
    }
    if ( $writer->isa('Genome::Utility::IO::StdoutRefWriter') ) {
        $self->error_message('Cannot write to a PIPE!');
        return;
    }

    while ( my $seqs = $reader->read ) {
        $writer->write($seqs);
    }

    return 1;
}

sub _open_reader_and_writer {
    my $self = shift;

    my $reader_class = $self->_reader_class;
    return if not $reader_class;

    my %reader_params;
    my @input = $self->input;
    if ( @input ) { # STDIN/FILES
        $reader_params{files} = \@input;
        $reader_params{is_paired} = $self->paired_input;
    }

    my $reader = eval{ $reader_class->create(%reader_params); };
    if ( not  $reader ) {
        $self->error_message("Failed to create reader for input: ".$self->_input_to_string);
        return;
    }
    $self->_reader($reader);

    my $writer_class = $self->_writer_class;
    return if not $writer_class;

    my %writer_params;
    my @output = $self->output;
    if ( @output ) { # STDOUT/FILES
        $writer_params{files} = \@output;
        $writer_params{is_paired} = $self->paired_output;
    }

    my $writer = eval{ $writer_class->create(%writer_params); };
    if ( not $writer ) {
        $self->error_message('Failed to create writer for output ('.$self->_output_to_string.'): '.($@ || 'no error'));
        return;
    }

    if ( $self->metrics_file_out ) {
        $writer->metrics( Genome::Model::Tools::Sx::Metrics->create() );
    }

    $self->_writer($writer);

    return ( $self->_reader, $self->_writer );
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

            if ( not $self->_writer ) {
                Carp::confess('No writer found!');
            }

            # Skip if we don't have a metrics file
            my $metrics_file = $self->metrics_file_out;
            return 1 if not $self->metrics_file_out;

            # Problem if the writer or writer metric object does not exist
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

