
package Genome::Model::Tools::ViromeEvent::BlastX_Viral::PoolAndSplitSequence;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;
use Bio::SeqIO;
use File::Basename;

class Genome::Model::Tools::ViromeEvent::BlastX_Viral::PoolAndSplitSequence{
    is => 'Genome::Model::Tools::ViromeEvent',
};

sub help_brief {
    return "gzhao's Blast x Pool and Split Sequence";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
This script will put all sequences in all BXfiltered.fa files in given
sample library into one .BXfiltered.fa file.

Given a fasta file, this script will split it to a number of files. Each 
file will contain given number of sequences. Generated files have the 
same name as the given file with numbered suffix .file0 .file1 ... etc 
All the generated files are placed in on subdirectory with the same name 
as the given file with "BXfiltered_TBLASTX_Viral" suffix. 

perl script <sample dir>
<sample dir> = full path to the folder holding files for a sample library
               without last "/"
EOS
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return $self;

}

sub execute {
    my $self = shift;

    my $dir = $self->dir;
    my $sample_name = basename($dir);

    $self->log_event("Pooling data to run Viral BlastX for $sample_name");

    #CREATE VIRAL BLASTX DIR
    my $blast_dir = $dir.'/'.$sample_name.'.TBXNTFiltered_TBLASTX_ViralGenome';
    system("mkdir $blast_dir");
    unless (-d $blast_dir) {
	$self->log_event("Failed to create dir ".basename($blast_dir));
	return;
    }

    #DEFINE POOLED OUT FILE NAME AND POOL FILTERED READS TO THAT FILE
    my $pool_file = $dir.'/'.$sample_name.'.TBXNTFiltered.fa';
    my $out = Bio::SeqIO->new(-format => 'fasta', -file => ">$pool_file");

    #FIND PREVIOUS BLAST DIR
    my $nt_blastx_dir = $dir.'/'.$sample_name.'.BNFiltered_TBLASTX_nt';
    unless (-d $nt_blastx_dir) {
	$self->log_event("Failed to find NT blastX dir for $sample_name");
	return;
    }

    #CHECK TO MAKE SURE THERE'S DATA TO PROCEED
    my @nt_bx_files = glob("$nt_blastx_dir/*fa");
    if (@nt_bx_files == 0) {
	$self->log_event("No further data available for $sample_name");
	return 1;
    }

    #GLOB FILES THAT CONTAIN FILTERED READS
    my @filtered_files = glob("$nt_blastx_dir/*TBXNTfiltered.fa");
    unless (scalar @filtered_files > 0) {
	$self->log_event("Failed to find any NT blastX filtered data for $sample_name");
	return;
    }

    #POOL DATA INTO POOLED OUTPUT FILE
    foreach my $file (@filtered_files) {
	my $in = Bio::SeqIO->new(-format => 'fasta', -file => $file);
	while (my $seq = $in->next_seq) {
	    $out->write_seq($seq);
	}
    }

    unless (-s $pool_file) {
	$self->log_event("Failed to create pooled file of NT blastX filtered reads");
	return;
    }

    my $c = 0;  my $n = 0;  my $limit = 500;
    my $in = Bio::SeqIO->new(-format => 'fasta', -file => $pool_file);
    my $split_file = $blast_dir.'/'.$sample_name.'.TBXNTFiltered.fa_file'.$n.'.fa';
    my $split_out = Bio::SeqIO->new(-format => 'fasta', -file => ">$split_file");
    while (my $seq = $in->next_seq) {
	$c++;
	$split_out->write_seq($seq);
	if ($c == $limit) {
	    $c = 0;
	    $split_file = $blast_dir.'/'.$sample_name.'.TBXNTFiltered.fa_file'.++$n.'.fa';
	    $split_out = Bio::SeqIO->new(-format => 'fasta', -file => ">$split_file");
	}
    }

    $self->log_event("Completed pooling Viral BlastX data for $sample_name");

    return 1;
}

1;

