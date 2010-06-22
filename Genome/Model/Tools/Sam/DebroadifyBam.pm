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
    
    my $bam_output;
    unless($bam_output = IO::File->new("|samtools view -b -t ".$self->reference_file." - -o ".$self->output_bam_file)){
        $self->error_message("Could not open bam_output pipe.");
        die $self->error_message;
    }
    print "successfully opened bam output pipe.\n";
    my $sam_header_input;
    unless($sam_header_input = IO::File->new("samtools view -H ".$self->input_bam_file."|")) {
        $self->error_message("Could not open bam header input pipe");
        die $self->error_message;
    }
    print "successfully opened bam header input pipe.\n";
    while (<$sam_header_input>) {
        if (m/^\@SQ/) {
            $_=~s/\@SQ\tSN:chrM/\@SQ\tSN:MT/;
            $_=~s/\@SQ\tSN:chr(X|Y)/\@SQ\tSN:$1/;
            $_=~s/\@SQ\tSN:chr(.*)\w/\@SQ\tSN:$1/;
        }
        print $bam_output $_;
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
    
        print $bam_output join "\t", @sam_fields;
    }

    close $sam_input;
    close $bam_output;

    return 1;
}
