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
        input => {
            is => 'Text',
            is_many => 1,
            is_input => 1,
            doc => 'Input files, or "PIPE" if reading from another program. If multiple files are given for fastq types (sanger, illumina), one sequence will be read from each file and then handled as a set.',
            # TODO includes fasta:
            # doc => 'Input files, or "PIPE" if reading from another program. If multiple files are given for fastq types (sanger, illumina), one sequence will be read from each file and then handled as a set. If multiple files are given for type phred (fasta), the first file should be the sequences, and the second file should be the qualities.',
        }, 
        type_in => {
            is  => 'Text',
            default_value => 'sanger',
            is_optional => 1,
            is_input => 1,
            doc => 'The sequence and quality type of the input. Valid values are: '.join(' ', __PACKAGE__->valid_types).'.',
            # TODO includes phred (fasta):
            # doc => 'The sequence and quality type. If not given, an attempt will be made to guess the type. If the file ends in "fasta", "fna", or "fa", the type will assumed to be phred (fasta). If the file ends with "fastq", it will assumed to be sanger (fastq).',
        },
        output => {
            is => 'Text',
            is_many => 1,
            is_input => 1,
            doc => 'Output files, or "PIPE" if writing to another program. If multiple files are given for fastq types (sanger, illumina), one sequence from each set will be written to each file.',
            # TODO includes fasta: 
            # doc => 'Output files, or "PIPE" if writing from another program. If multiple files are given for fastq types (sanger, illumina), one sequence from each set will be written to each file. If multiple files are given for type phred (fasta), the sequences will be written to the first file, and the qualities will eb written to the second file.',
        },
        type_out => {
            is  => 'Text',
            default_value => 'sanger',
            is_optional => 1,
            is_input => 1,
            doc => 'The sequence and quality type of the output. Currently, this is ognored and the type of the input is used. Valid values are: '.join(' ', __PACKAGE__->valid_types).'.',
            # TODO includes phred (fasta):
            # doc => 'The sequence and quality type. If not given, an attempt will be made to guess the type. If the file ends in "fasta", "fna", or "fa", the type will assumed to be phred (fasta). If the file ends with "fastq", it will assumed to be sanger (fastq).',
        },
        metrics_file => {
            is => 'Text',
            is_optional => 1,
            doc => 'Output general sequence metrics to this file.',
        },
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

    my $type = $self->type_in;
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

#< Create >#
sub create {
    my ($class, %params) = @_;

    my $self = $class->SUPER::create(%params)
        or return;

    return $self;
}
#<>#

#< Reader Writer >#
sub _open_reader {
    my $self = shift;

    my @input = $self->input;
    unless ( @input ) {
        Carp::confess("Input files or 'PIPE' is required.");
    }

    if ( $input[0] eq 'PIPE' ) {
        return $self->_open_stdin_reader;
    }

    my $type = $self->_enforce_type
        or return;

    my $reader;
    eval{
        $reader = Genome::Model::Tools::FastQual::FastqSetReader->create(
            files => \@input,
        );
    };
    unless ( $reader ) {
        $self->error_message("Can't create fastq reader for input files (".join(', ', @input)."): $@");
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
    $self->type_in( $reader_info->{type} );
    $self->_enforce_type;
    
    return $reader;
}

sub _open_writer {
    my $self = shift;

    $DB::single = 1;
    my @output = $self->output;
    unless ( @output ) {
        Carp::confess("Output files or 'PIPE' is required.");
    }

    my $type = $self->_enforce_type
        or return;
    my $format = $self->format_for_type($type);

    my $writer;
    if ( $output[0] eq 'PIPE' ) {
        $writer = $self->_open_stdout_writer; # confess in sub
    }
    elsif ( $format eq  'fastq' ) {
        $writer = $self->_open_fastq_set_writer(@output); # confess in sub
    }
    else { 
        Carp::confess("Cannot open writer, unknown output type ($type).");
    }

    if ( $self->metrics_file ) {
        $self->_setup_write_observer($writer); # confess in sub
    }

    return $writer;
}

sub _open_stdout_writer {
    my $self = shift;

    # open stdout ref writer
    my $writer = Genome::Utility::IO::StdoutRefWriter->create
        or Carp::confess("Can't open pipe to STDOUT");
    # write the meta info - TODO output type
    $writer->write({ type => $self->type_in });

    return $writer;
}

sub _open_fastq_set_writer {
    my ($self, @output) = @_;

    my $writer;
    eval{
        $writer = Genome::Model::Tools::FastQual::FastqSetWriter->create(
            files => \@output,
        );
    };
    unless ( $writer ) {
        Carp::confess("Can't create fastq set writer for output files (".join(', ', @output)."): $@");
    }

    return $writer;
}

my %writers_observed;
my @writer_classes_overloaded;
my $result_obeserver;
sub _setup_write_observer {
    my ($self, $writer) = @_;

    unless ($writer ) {
        Carp::confess('No writer given to setup observer.');
    }

    my $writer_class = ref($writer);
    unless ($writer_class ) {
        Carp::confess('No class for writer to setup observer.');
    }

    my $writer_id = $writer->id;
    unless ( $writer_id ) {
        Carp::confess('No id for writer: '.Dumper$writer);
    }

    # Writer Class and ID - set in writers observed, 
    my $writer_class_id = $writer_class.' '.$writer_id;
    return 1 if exists $writers_observed{$writer_class_id};
    $writers_observed{$writer_class_id} = { bases => 0, count => 0, };

    # Is this writer class overloaded?
    unless (  grep { $writer_class eq $_ } @writer_classes_overloaded ) {
        my $write_method = $writer_class.'::write';
        my $write = \&{$write_method};
        no strict 'refs';
        no warnings 'redefine';
        *{$write_method} = sub{ 
            $write->(@_); 
            my $writer_class_id = ref($_[0]).' '.$_[0]->id;
            unless ( exists $writers_observed{$writer_class_id} ) {
                # skip if not observing this writer
                return 1;
            }
            # add to metrics
            for ( @{$_[1]} ) { 
                $writers_observed{$writer_class_id}->{bases} += length($_->{seq});
                $writers_observed{$writer_class_id}->{count}++;
            }
            return 1;
        }; 
        use strict;
        use warnings;
        push @writer_classes_overloaded, $writer_class;
    }

    # Result observer, so we know when the command has been executed. Only need one for all FastQual commands
    unless ( $result_obeserver ) {
        $result_obeserver = $self->add_observer(
            aspect => 'result',
            callback => sub {
                my ($self, $method, $prior_value, $value) = @_;

                return unless $value; # don't output metrics if excute failed, or was not called

                my $metrics_file = $self->metrics_file;
                unlink $metrics_file if -e $metrics_file;
                my $fh;
                eval{
                    $fh= Genome::Utility::FileSystem->open_file_for_writing($metrics_file);
                };
                unless ( $fh ) {
                    Carp::confess("Cannot open metrics file ($metrics_file) for writing: $@");
                }
                for my $stat ( sort keys %{$writers_observed{$writer_class_id}}) {
                    $fh->print( $stat.'='.$writers_observed{$writer_class_id}->{$stat}."\n");
                }
                return 1;
            }
        );
        unless ( $result_obeserver ) {
            Carp::confess('Cannot create observer for property "result"');
        }
    }

    return 1;
}

1;

