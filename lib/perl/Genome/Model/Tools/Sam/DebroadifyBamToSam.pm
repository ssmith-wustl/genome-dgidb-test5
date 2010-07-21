package Genome::Model::Tools::Sam::DebroadifyBamToSam;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
use File::Basename;

class Genome::Model::Tools::Sam::DebroadifyBamToSam {
    is  => 'Genome::Model::Tools::Sam',
    has => [
	input_bam_file => {
	    is  => 'Text',
	    doc => 'full path to Input BAM File',
	},
	output_sam_file => {
	    is => 'Text',
	    doc => 'Output SAM File with path',
	},
        reference_file => {
            is => 'Text',
            is_optional => 1,
            doc => 'fill path to the reference to build the output bam against',
        },
    ],
};

sub execute {
    my $self = shift;

    #Check to see that the input file exists.
    unless(-e $self->input_bam_file) {
        $self->error_message("could not locate input file ".$self->input_bam_file);
        die $self->error_message;
    }

    #If a reference_file has been specified, make sure it exists.
    if(defined($self->reference_file)) {
        unless(-e $self->reference_file) {
           $self->error_message("Couldn't find reference file $self->reference_file");
            die $self->error_message;
        }
    }
    
    my $sam_header_input;
    my $sam_header_input_command = 'samtools view -H '.$self->input_bam_file.'|';

    #Open the BAM file's header for streaming.
    unless($sam_header_input = IO::File->new($sam_header_input_command)) {
        $self->error_message("Could not open bam header input pipe");
        die $self->error_message;
    }
    $self->status_message("Opening BAM header for conversion to SAM\n");
    print $self->status_message;


    #Open a file to append the BAM to SAM output to.
    my $sam_output = new IO::File;
    $sam_output->open(">> ".$self->output_sam_file);
    print "opened sam_output file handle\n";

    #Verify that the output file was opened successfully.
    unless($sam_output){
        $self->error_message("Could not open bam_output pipe.");
        die $self->error_message;
    }
    $self->status_message("Opening file in which to place SAM data.\n");
    print $self->status_message;

    #Read data from the BAM header, remove the /chr/ from chromosome names, 
    # then stuff the data into the output SAM file.
    while (<$sam_header_input>) {
        if (m/^\@SQ/) {
            $_=~s/\@SQ\tSN:chr(\d+)/\@SQ\tSN:$1/;
            $_=~s/\@SQ\tSN:chrM/\@SQ\tSN:MT/;
        }
        print $sam_output $_;
        #print STDOUT $_."\n";
    }
    close $sam_header_input;

    $self->status_message("Finished processing BAM header, closing BAM header filehandle.\n");
    print $self->status_message;

    my $sam_input;
    my $sam_input_command = "samtools view ".$self->input_bam_file." |";
    unless($sam_input = IO::File->new($sam_input_command)) {
        $self->error_message("Could not open bam input pipe");
        die $self->error_message;
    }
    $self->status_message("Opened BAM file for streaming.\n");
    print $self->status_message;

    #Read data from BAM file and fix chromosome labels.
    while (<$sam_input>) {
        my @sam_fields = split /\t/;

        $sam_fields[2] =~ s/^chr(\d+)$/$1/;
        $sam_fields[6] =~ s/^chr(\d+)$/$1/;
        $sam_fields[2] =~ s/^chrM$/MT/;
        $sam_fields[6] =~ s/^chrM$/MT/;
    
        print $sam_output join "\t", @sam_fields;
    }
    $self->status_message("Finished fixing BAM file.\n");
    print $self->status_message;

    close $sam_input;
    close $sam_output;

    return 1;
}
