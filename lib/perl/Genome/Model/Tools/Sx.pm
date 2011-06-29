package Genome::Model::Tools::Sx;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Sx {
    is  => 'Command',
    has => [
        input => {
            is => 'Text',
            is_many => 1,
            is_optional => 1,
            doc => <<DOC
Input reader configurations. Give 'key=value' pairs, separated by a colon (:). Readers may have additonal options.

Do not use this option when piping from sx commands.

Standard options:
 file => The file to read. The use of the preceding 'file=' is optional.
          It is assumed that the bare option is the file. Use '-' to read from STDIN.
 type => The type of input. Not required if type can be determined from the file.
          Required when reading from STDIN. Valid types: sanger, illumina, phred.
 cnt => The number of sequences to read from the input. If the input is paired, use 2.

Additional options, by type:
 phred
  qual_file => read qualities from this file.

DOC
        }, 
        _reader => { is_optional => 1, },
        output => {
            is => 'Text',
            is_many => 1,
            is_optional => 1,
            doc => <<DOC
Output writer configurations. Give 'key=value' pairs, separated by a colon (:). Writers may have additonal options.

Do not use this option when piping from sx commands.

Standard options:
 file => The file to write. The use of the preceding 'file=' is optional.
          It is assumed that the bare option is the file. Use '-' to write to STDOUT.
 type => The type of output. Not required if type can be determined from the file.
          Required when writing to STDOUT. Valid types: sanger, illumina, phred, bed.
 name => The name of the writer.  If using commands that attach a writer name to a sequence,
          they will be written to the specified writer.
          
          Names pair, fwd, rev and sing are reserved. They have special behavior, and don't
           require the underlying command to tag writer names to sequences.
          Examples:
          name=pair:FILE
           write only pairs
          name=pair:FILE name=sing:FILE2
           write pairs to one and singletons to another
          name=fwd:FILE name=rev:FILE2
           write first sequence to fwd, second to rev, discard singletons
          name=fwd:FILE name=rev:FILE2 name=sing:FILE3
           write first sequence to fwd, second to rev, singletons to sing
          name=sing:FILE
           write singletons to sing, discardc pairs


Additional options, by type:
 phred
  qual_file => write qualities to this file

DOC
        },
        _writer => { is_optional => 1, },
        metrics_file_out => {
            is => 'Text',
            is_optional => 1,
            doc => 'Output sequence metrics for the output to this file. Current metrics include: count, bases',
        },
    ],
};

sub help_brief {
    return 'Transform sequences';
}

sub help_synopsis {
    return <<HELP;
    Transform sequences. See sub-commands for a additional functionality.

    Types Handled
    * sanger => fastq w/ snager quality values
    * illumina => fastq w/ illumina quality values
    * phred => fasta/quality

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

HELP
}

sub help_detail {
    return <<HELP;

 Input/Ouptut format:
 * Short, where type can be determined from the file:
  gmt sx --input file.fastq --output file.fasta # qual file not written

 * Long w/ file and type:
  gmt sx --input file=file.fastq:type=illumina --output file=file.fasta:qual_file=file.qual:type:phred

 What this base command can do:
 * Convert type
  ** illumina fastq to sanger
   gmt sx --input illumina.fastq:type=illumina --output sanger.fastq
  ** sanger fastq to phred fasta
   gmt sx --input file.fastq --output file.fasta
  ** sanger fastq to phred fasta w/ quals
   gmt sx --input file.fastq --output file.fasta:qual_file=file.qual

 * Collate
  ** from paired fastqs (type-in resolved to sanger, type-out defaults to sanger)
   gmt sx --input fwd.fastq rev.fastq --output collated.fastq
  ** to paired STDOUT (type-in resolved to sanger, type-out defaults to sanger)
   gmt sx --input fwd.fastq rev.fastq --output -

 * Decollate
  ** from illumina to individal fastqs, discard singletons
   gmt sx --input collated.fastq --output fwd.fastq:name=fwd rev.fastq,name=rev
  ** from paired illumina STDIN (type-in req'd = illumina, type-out defaults to sanger)
   gmt sx --input -:name=pair:type=illumnia --output fwd.fastq:name=fwd rev.fastq:name=rev

 * Use in PIPE (cmd represents a sx sub command)
  ** from singleton fastq file
   gmt sx cmd1 --cmd1-options --input sanger.fastq | gmt sx cmd2 --cmd2-options --output sanger.fastq
  ** from paired STDIN to paired fastq and singleton (assuming the sub commands filter singletons)
   cat collated_fastq | gmt sx cmd1 --cmd1-options --input - --paired-input | gmt sx cmd2 --cmd2-options --output pairs.fastq

HELP
}

sub _init {
    my $self = shift;

    my @input = $self->input;
    @input = (qw/ stdinref /) if not @input;
    my $reader = Genome::Model::Tools::Sx::Reader->create(config => \@input);
    return if not $reader;
    $self->_reader($reader);

    my @output = $self->output;
    @output = (qw/ stdoutref /) if not @output;
    my %writer_params = (
        config => \@output,
    );
    if ( $self->metrics_file_out ) {
        my $metrics = Genome::Model::Tools::Sx::Metrics->create();
        return if not $metrics;
        $writer_params{metrics} = $metrics;
    }
    my $writer = Genome::Model::Tools::Sx::Writer->create(%writer_params);
    return if not $writer;
    $self->_writer($writer);

    $self->_add_result_observer;  #confesses on error

    return 1;
}

sub execute {
    my $self = shift;

    my $init = $self->_init;
    return if not $init;

    my $reader = $self->_reader;
    my $writer = $self->_writer;

    while ( my $seqs = $reader->read ) {
        $self->_eval_seqs($seqs) or return;
        next if not @$seqs;
        $writer->write($seqs);
    }

    return 1;
}

sub _eval_seqs { return 1; }

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

