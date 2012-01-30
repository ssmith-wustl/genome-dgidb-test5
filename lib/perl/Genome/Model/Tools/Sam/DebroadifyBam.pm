package Genome::Model::Tools::Sam::DebroadifyBam;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
use File::Basename;
use List::Util qw(first);

class Genome::Model::Tools::Sam::DebroadifyBam {
    is  => 'Genome::Model::Tools::Sam',
    has => [
	input_bam_file => {
	    is  => 'Text',
	    doc => 'full path to Input BAM File',
	},
	output_bam_file => {
	    is => 'Text',
	    doc => 'Output BAM File with path',
	},
        reference_file => {
            is => 'Text',
            doc => 'fill path to the reference to build the output bam against',
        },
        use_fillmd => {
            is => 'Text',
            is_optional => '1',
            doc => 'Pass any value to this if fillmd should be run on the bam.',
        }, 
        output_sam => {
            is => 'Text',
            is_optional => '1',
            doc => 'Pass any value to this if you wish to output a SAM rather than a BAM to output_file',
        },
    ],
};

sub execute {
    my $self = shift;
   
    #Do some checks before we get going to ensure all the inputs are available and things will work.

    unless(defined($self->output_sam)){
        unless(defined($self->reference_file)){
            $self->error_message("In order to output a BAM file, a reference_file must be provided.");
            die $self->error_message;
        }
        unless(-e $self->reference_file) {
            $self->error_message("Couldn't find reference file located at: $self->reference_file");
            die $self->error_message;
        }
    }
    unless(-e $self->input_bam_file) {
        $self->error_message("could not locate input file located at: ".$self->input_bam_file);
        die $self->error_message;
    }

    unless(-e $self->reference_file) {
        $self->error_message("Couldn't find reference file $self->reference_file");
        die $self->error_message;
    }
    
    my $tmp_bam_output_file = Genome::Sys->create_temp_file_path();
    my $tmp_bam_output = IO::File->new("|samtools view -b -T " . $self->reference_file . " - -o $tmp_bam_output_file");
    unless ($tmp_bam_output) {
        $self->error_message("Could not open tmp_bam_output pipe.");
        die $self->error_message;
    }
    print "successfully opened bam output pipe.\n";

    my $sam_header_input;
    unless($sam_header_input = IO::File->new("samtools view -H ".$self->input_bam_file."|")) {
        $self->error_message("Could not open bam header input pipe");
        die $self->error_message;
    }
    print "successfully opened bam header input pipe.\n";

    while (my $line = $sam_header_input->getline) {
        if ($line =~ /^\@SQ/) {
            # Convert Broad chromosome names to TGI.
            $line =~ s/\@SQ\tSN:chrM/\@SQ\tSN:MT/;
            $line =~ s/\@SQ\tSN:chr(X|Y)/\@SQ\tSN:$1/;
            $line =~ s/\@SQ\tSN:chr(.*)\w/\@SQ\tSN:$1/;
        }
        print $tmp_bam_output $line;
    }
    close $sam_header_input;


    my $sam_input;
    unless($sam_input = IO::File->new("samtools view ".$self->input_bam_file."|")) {
        $self->error_message("Could not open bam input pipe");
        die $self->error_message;
    }
    print "successfully opened bam input pipe.\n";
    while (<$sam_input>) {
        my @sam_fields = split /\t/;

        $sam_fields[2] =~ s/^chrM$/MT/;
        $sam_fields[2] =~ s/^chr(.*)(_|\w)/$1$2/;
        $sam_fields[6] =~ s/^chrM$/MT/;
        $sam_fields[6] =~ s/^chr(.*)(_|\w)/$1$2/;
    
        print $tmp_bam_output join "\t", @sam_fields;
    }

    close $sam_input;
    close $tmp_bam_output;

    my $reorder_cmd = Genome::Model::Tools::Picard::ReorderSam->create(
        input_file => $tmp_bam_output_file,
        output_file => $self->output_bam_file,
        reference_file => $self->reference_file,
    );
    unless ($reorder_cmd->execute) {
        die 'failed to execute reorder_cmd';
    }

    return 1;
}
