package Genome::Model::Tools::Sam::Debroadify;

use strict;
use warnings;

use Genome;
use IO::File;

class Genome::Model::Tools::Sam::Debroadify {
    is  => 'Genome::Model::Tools::Sam',
    has => [
        input_file => {
            is  => 'Text',
            doc => 'Full path to input SAM/BAM.',
        },
        output_file => {
            is => 'Text',
            doc => 'Full path to output SAM/BAM.',
        },
        reference_file => {
            is => 'Text',
            doc => 'Full path to the reference FASTA to build the output BAM/SAM against.',
        },
    ],
};

sub validate_inputs {
    my $self = shift;
    if ($self->output_file =~ /\.bam$/ && ! defined $self->reference_file) {
        die $self->error_message('In order to output a BAM file, a reference_file must be provided.');
    }
    if (defined $self->reference_file && ! -e $self->reference_file) {
        die $self->error_message('Could not find reference file at: ' . $self->reference_file);
    }
    unless (-e $self->input_file) {
        die $self->error_message('Could not locate input file located at: ' . $self->input_file);
    }
    return 1;
}

sub samtools_output_options {
    my $self = shift;
    my @samtools_output_options;
    if ($self->output_file =~ /\.bam$/) {
        push @samtools_output_options, '-b';
    }
    if ($self->reference_file) {
        push @samtools_output_options, '-T ' . $self->reference_file;
    }
    return join(' ', @samtools_output_options);
}

sub samtools_input_options {
    my $self = shift;
    my @samtools_input_options;
    if ($self->input_file =~ /\.sam$/) {
        push @samtools_input_options, '-S';
    }
    return join(' ', @samtools_input_options);
}

sub execute {
    my $self = shift;

    $self->validate_inputs();

    my $samtools_output_options = $self->samtools_output_options();
    my $tmp_output_file = Genome::Sys->create_temp_file_path();
    my $tmp_output = IO::File->new("| samtools view $samtools_output_options -o $tmp_output_file -");
    unless ($tmp_output) {
        die $self->error_message('Could not open the (temp) output pipe.');
    }

    my $samtools_input_options = $self->samtools_input_options();
    my $input = IO::File->new("samtools view -h $samtools_input_options " . $self->input_file . ' |');
    unless ($input) {
        die $self->error_message('Could not open the input pipe.');
    }
    $self->status_message('Converting Broad chromosome references to TGI style.');
    $self->status_message('output will be at: ' . $tmp_output_file);
    while (my $line = $input->getline) {
        if ($line =~ /^\@SQ/ && $line =~ /chr/) {
            $line =~ s/\@SQ\tSN:chrM/\@SQ\tSN:MT/;
            $line =~ s/\@SQ\tSN:chr(X|Y)/\@SQ\tSN:$1/;
            $line =~ s/\@SQ\tSN:chr(.*)\w/\@SQ\tSN:$1/;
        }
        if ($line !~ /^\@/ && $line =~ /chr/) {
            my @sam_fields = split("\t", $line);
            $sam_fields[2] =~ s/^chrM$/MT/;
            $sam_fields[2] =~ s/^chr(.*)(_|\w)/$1$2/;
            $sam_fields[6] =~ s/^chrM$/MT/;
            $sam_fields[6] =~ s/^chr(.*)(_|\w)/$1$2/;
            $line = join("\t", @sam_fields);
        }
        print $tmp_output $line;
    }
    close $input;

    close $tmp_output;

    # This needs to be done because Broad's reference is sorted 1-22,X,Y but our is 1-9,X,Y,10-22.
    $self->status_message('Reordering BAM to match reference.');
    $self->status_message('output will be at: ' . $self->output_file);
    my $reorder_cmd = Genome::Model::Tools::Picard::ReorderSam->create(
        input_file => $tmp_output_file,
        output_file => $self->output_file,
        reference_file => $self->reference_file,
    );
    unless ($reorder_cmd->execute) {
        die 'failed to execute reorder_cmd';
    }

    return 1;
}
