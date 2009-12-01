package Genome::Model::Tools::Sam::BamToFastq;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
use File::Basename;

class Genome::Model::Tools::Sam::BamToFastq {
    is  => 'Genome::Model::Tools::Sam',
    has => [
	bam_file => {
	    is  => 'String',
	    doc => 'Input File',
	},
	fastq_file => {
	    is => 'Boolean',
	    is_optional => 1,
	    doc => 'Output File',
	},
    ],
};

sub execute {
    my $self = shift;
    
    my ($input_basename,$input_dirname,$input_suffix) = File::Basename::fileparse($self->bam_file,qw/bam/);
    $input_basename =~ s/\.$//;

    unless ($self->fastq_file) {
        $self->fastq_file($input_dirname .'/'. $input_basename .'.txt');
    }
    my ($output_basename,$output_dirname,$output_suffix) = File::Basename::fileparse($self->fastq_file,qw/txt fastq fq/);
    my $tmp_dir = File::Temp::tempdir( DIR => $output_dirname, CLEANUP => 1 );
    my $tmp_sam_file = $tmp_dir .'/'. $input_basename .'.sam';
    my $cmd = $self->samtools_path .' view -o '. $tmp_sam_file .' '. $self->bam_file;
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
        input_files => [$self->bam_file],
        output_files => [$tmp_sam_file],
    );
    my $in_sam_fh = IO::File->new($tmp_sam_file,'r');
    my $fastq_fh = IO::File->new($self->fastq_file,'w');
    while (my $line = $in_sam_fh->getline) {
        chomp($line);
        my @entry = split("\t",$line);
        my $read_name = $entry[0];
        my $seq = $entry[9];
        my $qual = $entry[10];
        print $fastq_fh '@'. $read_name ."\n". $seq ."\n+\n". $qual ."\n";
    }
    $in_sam_fh->close;
    $fastq_fh->close;
    return 1;
}
