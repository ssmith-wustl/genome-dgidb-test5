package Genome::Model::Tools::Sam::BamToSam;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
use File::Basename;

class Genome::Model::Tools::Sam::BamToSam {
    is  => 'Genome::Model::Tools::Sam',
    has => [
	bam_file => {
	    is  => 'Text',
	    doc => 'Input BAM File',
	},
	sam_file => {
	    is => 'Text',
	    is_optional => 1,
	    doc => 'Output BAM File - default name is derived from input BAM file. example.bam will generate example.sam',
	},
    ],
};

sub execute {
    my $self = shift;
    my ($input_basename,$input_dirname,$input_suffix) = File::Basename::fileparse($self->bam_file,qw/\.bam/);
    unless ($self->sam_file) {
        $self->sam_file($input_dirname .'/'. $input_basename .'.sam');
    }
    my ($output_basename,$output_dirname,$output_suffix) = File::Basename::fileparse($self->sam_file,qw/sam/);


    my $input_stream = "samtools view ".$self->bam_file."|";
    
    my $input_fh = IO::File->new($input_stream);
    unless($input_fh) {
        $self->error_message("Could not open input BAM file with the following command\n\t".$input_stream);
        die $self->error_message;
    }
    my $output_stream = ">> ".$self->sam_file;
    my $output_fh = IO::File->new($output_stream);
    unless($output_fh) {
        $self->error_message("Could not open output file with the following command\n\t".$output_stream);
        die $self->error_message;
    }
    while(<$input_fh>) {
        print $output_fh $_;
    }
    close $input_fh;
    close $output_fh;

    return 1;
}


1;
