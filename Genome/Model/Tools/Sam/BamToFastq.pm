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
	    is  => 'Text',
	    doc => 'Input BAM File',
	},
	fastq_file => {
	    is => 'Text',
	    is_optional => 1,
	    doc => 'Output FASTQ File',
	},
        include_flag => {
            is => 'Text',
            is_optional => 1,
            doc => 'A bit-wise flag used to include specific alignments/reads:
               0x0001 => the read is paired in sequencing,
               0x0002 => the read is mapped in a proper pair,
               0x0004 => the query sequence itself is unmapped,
               0x0008 => the mate is unmapped,
               0x0010 => strand of query (0 for forward; 1 for reverse strand),
               0x0020 => strand of mate,
               0x0040 => the read is the first read in a pair,
               0x0080 => the read is the second read in a pair,
               0x0100 => the alignment is not primary,
               0x0200 => the read failes platform/vendor quality checks,
               0x0400 => the read is either a PCR duplicate or an optical duplicate',
        },
        exclude_flag => {
            is => 'Text',
            is_optional => 1,
            doc => 'A bit-wise flag use to exclude specific alignments/reads:  see options for include_flag',
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
    my $params = ' -o '. $tmp_sam_file;
    if ($self->include_flag) {
        $params .= ' -f '. $self->include_flag;
    }
    if ($self->exclude_flag) {
        $params .= ' -F '. $self->exclude_flag;
    }
    my $cmd = $self->samtools_path .' view '. $params .' '. $self->bam_file;
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
