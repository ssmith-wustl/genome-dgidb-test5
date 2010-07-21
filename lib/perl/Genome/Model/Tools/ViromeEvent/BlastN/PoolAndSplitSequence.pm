
package Genome::Model::Tools::ViromeEvent::BlastN::PoolAndSplitSequence;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;
use Bio::SeqIO;
use File::Basename;

class Genome::Model::Tools::ViromeEvent::BlastN::PoolAndSplitSequence{
    is => 'Genome::Model::Tools::ViromeEvent',
};

sub help_brief {
    return "gzhao's Blast N Pool and Split Sequence";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
This script will put all sequences in all HGFiltered.fa files in given
sample library into one .HGfiltered.fa file.

Given a fasta file, this script will split it to a number of files. Each 
file will contain given number of sequences. Generated files have the 
same name as the given file with numbered suffix .file0 .file1 ... etc 
All the generated files are placed in on subdirectory with the same name 
as the given file with "_library" suffix. 


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

    $self->log_event("Pooling data to run NT blastN for $sample_name");

    #CREATE DIRECTORY FOR NT BLASTN
    my $nt_blast_dir = $dir.'/'.$sample_name.'.HGfiltered_BLASTN';
    system("mkdir $nt_blast_dir");
    unless (-d $nt_blast_dir) {
	$self->log_event("Failed to create NT blast dir".basename($nt_blast_dir));
	return;
    }

    #DEFINE OUTPUT FASTA TO POOL READS INTO
    my $pooled_file = $dir.'/'.$sample_name.'.HGfiltered.fa';
    my $out_io = Bio::SeqIO->new(-format => 'fasta', -file => ">$pooled_file");

    #FIND HG BLAST DATA DIR
    my $hg_blast_dir = $dir.'/'.$sample_name.'.fa.cdhit_out.masked.goodSeq_HGblast';
    unless (-d $hg_blast_dir) {
	$self->log_event("Failed to find HG blast dir for $sample_name");
	return;
    }

    #CHECK TO MAKE SURE THERE'S DATA AVAILABLE TO PROCEED
    my @hg_bl_files = glob("$hg_blast_dir/*fa");
    if (@hg_bl_files == 0) {
	$self->log_event("No further data available for $sample_name");
	return 1;
    }

    #FIND FILES THAT CONTAIN HG BLAST FILTERED READS
    my @filtered_reads = glob ("$hg_blast_dir/*HGfiltered.fa");
    unless (scalar @filtered_reads > 0) {
	$self->log_event("Failed to find any HG blast filtered data for $sample_name");
	return;
    }

    #POOL READS INTO POOLED FILE
    foreach (@filtered_reads) {
	my $in = Bio::SeqIO->new(-format => 'fasta', -file => $_);
	#TODO - JUST CAT >> INSTEAD??
	while (my $seq = $in->next_seq) {
	    $out_io->write_seq($seq);
	}
    }

    #CHECK
    unless (-d $nt_blast_dir) {
	$self->log_event("Failed to create NT blast dir".basename($nt_blast_dir));
	return;
    }

    my $c = 0; my $n = 0; my $limit = 500;
    my $in = Bio::SeqIO->new(-format => 'fasta', -file => $pooled_file);
    my $split_file = $nt_blast_dir.'/'.$sample_name.'.HGfiltered.fa_file'.$n.'.fa';
    my $split_out_io = Bio::SeqIO->new(-format => 'fasta', -file => ">$split_file");
    while (my $seq = $in->next_seq) {
	$c++;
	$split_out_io->write_seq($seq);
	if ($c == $limit) {
	    $c = 0;
	    $split_file = $nt_blast_dir.'/'.$sample_name.'.HGfiltered.fa_file'.++$n.'.fa';
	    $split_out_io = Bio::SeqIO->new(-format => 'fasta', -file => ">$split_file");
	}
    }

    $self->log_event("Pooling data to run NT blastN completed for $sample_name");

    return 1;
}

1;
