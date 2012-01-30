package Genome::Model::Tools::Sam::DebroadifyBam;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
use File::Basename;

class Genome::Model::Tools::Sam::DebroadifyBam {
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

sub execute {
    my $self = shift;

    if ($self->output_file =~ /\.bam$/ && ! defined $self->reference_file) {
        die $self->error_message("In order to output a BAM file, a reference_file must be provided.");
    }

    if (defined $self->reference_file && ! -e $self->reference_file) {
        die $self->error_message("Could not find reference file at: " . $self->reference_file);
    }

    unless (-e $self->input_file) {
        die $self->error_message("Could not locate input file located at: " . $self->input_file);
    }

    my $tmp_output_file = Genome::Sys->create_temp_file_path();
    my $tmp_output = IO::File->new("|samtools view -b -T " . $self->reference_file . " - -o $tmp_output_file");
    unless ($tmp_output) {
        die $self->error_message("Could not open tmp_output pipe.");
    }

    my $sam_header_input;
    unless($sam_header_input = IO::File->new("samtools view -H " . $self->input_file . "|")) {
        die $self->error_message("Could not open bam header input pipe");
    }

    while (my $line = $sam_header_input->getline) {
        if ($line =~ /^\@SQ/) {
            # Convert Broad chromosome names to TGI.
            $line =~ s/\@SQ\tSN:chrM/\@SQ\tSN:MT/;
            $line =~ s/\@SQ\tSN:chr(X|Y)/\@SQ\tSN:$1/;
            $line =~ s/\@SQ\tSN:chr(.*)\w/\@SQ\tSN:$1/;
        }
        print $tmp_output $line;
    }
    close $sam_header_input;


    my $sam_input;
    unless($sam_input = IO::File->new("samtools view " . $self->input_file . "|")) {
        die $self->error_message("Could not open bam input pipe");
    }
    while (<$sam_input>) {
        my @sam_fields = split /\t/;

        $sam_fields[2] =~ s/^chrM$/MT/;
        $sam_fields[2] =~ s/^chr(.*)(_|\w)/$1$2/;
        $sam_fields[6] =~ s/^chrM$/MT/;
        $sam_fields[6] =~ s/^chr(.*)(_|\w)/$1$2/;

        print $tmp_output join "\t", @sam_fields;
    }
    close $sam_input;
    close $tmp_output;

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
