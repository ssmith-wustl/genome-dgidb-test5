
package Genome::Model::Tools::ViromeEvent::BlastX_NT::PoolAndSplitSequence;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;
use Bio::SeqIO;
use File::Basename;

class Genome::Model::Tools::ViromeEvent::BlastX_NT::PoolAndSplitSequence{
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
This script will put all sequences in all BNfiltered.fa files in given
sample library into one .BNfiltered.fa file.

Given a fasta file, this script will split it to a number of files. Each 
file will contain given number of sequences. Generated files have the 
same name as the given file with numbered suffix .file0 .file1 ... etc 
All the generated files are placed in on subdirectory with the same name 
as the given file with "BNfiltered" suffix. 


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

    $self->log_event("Pooling data to run NT blastX for $sample_name");

    #CREATE NT BLASTX DIRECTORY
    my $blast_dir = $dir.'/'.$sample_name.'.BNFiltered_TBLASTX_nt';
    system ("mkdir $blast_dir");
    unless (-d $blast_dir) {
	$self->log_event("Failed to create dir ".basename($blast_dir));
	return;
    }

    #DEFINE POOLED OUT FILE NAME POOL FILTER READS TO THAT FILE
    my $pooled_file = $dir.'/'.$sample_name.'.BNFiltered.fa';
    my $out = Bio::SeqIO->new(-format => 'fasta', -file => ">$pooled_file");

    #FIND NT BLASTN DATA DIR (PREVIOUS BLAST RUN)
    my $nt_blastn_dir = $dir.'/'.$sample_name.'.HGfiltered_BLASTN';
    unless (-d $nt_blastn_dir) {
	$self->log_event("Failed to find NT blastN data dir for $sample_name");
	return;
    }

    #CHECK TO MAKE SURE THERE IS DATA TO PROCEED
    my @nt_bl_files = glob("$nt_blastn_dir/*fa");
    if (@nt_bl_files == 0) {
	$self->log_event("No further data available for $sample_name");
	return 1;
    }

    #FIND FILES THAT CONTAIN BLASTN FILTERED READS
    my @filtered_files = glob("$nt_blastn_dir/*BNfiltered.fa");
    unless (scalar @filtered_files > 0) {
	$self->log_event("Failed to find any NT blastN filtered data for $sample_name");
	return;
    }

    #POOL READS INFO POOLED OUTPUT FILE
    foreach my $file (@filtered_files) {
	my $in = Bio::SeqIO->new(-format => 'fasta', -file => $file);
	while (my $seq = $in->next_seq) {
	    $out->write_seq($seq);
	}
    }

    #CHECK TO MAKE SURE VALID POOLED FILE HAS BEEN MADE
    unless (-s $pooled_file) {
	$self->log_event("Failed to create pooled file of NT blastN filtered reads");
	return;
    }

    my $c = 0; my $n = 0; my $limit = 250;
    my $in = Bio::SeqIO->new(-format => 'fasta', -file => $pooled_file);
    my $split_file = $blast_dir.'/'.$sample_name.'.BNFiltered.fa_file'.$n.'.fa';
    my $split_out = Bio::SeqIO->new(-format => 'fasta', -file => ">$split_file");
    while (my $seq = $in->next_seq) {
	$c++;
	$split_out->write_seq($seq);
	if ($c == $limit) {
	    $c = 0;
	    $split_file = $blast_dir.'/'.$sample_name.'.BNFiltered.fa_file'.++$n.'.fa';
	    $split_out = Bio::SeqIO->new(-format => 'fasta', -file => ">$split_file");
	}
    }

    $self->log_event("Pooled data to run NT blast X completed for $sample_name");

    return 1;
}

1;

