package Genome::Model::Tools::Assembly::CreateOutputFiles::InputFromFastq;

use strict;
use warnings;

use Genome;

use Genome::Model::Tools::FastQual::FastqReader;

use IO::File;
use Bio::SeqIO;

class Genome::Model::Tools::Assembly::CreateOutputFiles::InputFromFastq {
    is => 'Genome::Model::Tools::Assembly::CreateOutputFiles',
    has => [
	fastq_file => {
	    is => 'Text',
	    doc => 'Input fastq file for the assembly',
	},
	directory => {
	    is => 'Text',
	    doc => 'Assembly data directory',
	},
    ],
};

sub help_brief {
    'Tool to create input fasta and qual from fastq file for stats',
}

sub help_detail {
    "Tool to create fasta and quality files from velvet input fastq file";
}

sub execute {
    my $self = shift;

    my $root_name = File::Basename::basename($self->fastq_file);
    $root_name =~ s/\.fastq//;

    my $fasta_file = $self->directory.'/edit_dir/'.$root_name.'.fasta';
    my $qual_file = $self->directory.'/edit_dir/'.$root_name.'.fasta.qual';

    #if this re-runs in automated pipline, previously created zipped files
    #must be removed for newly created files to zip

    my $f_out = Bio::SeqIO->new(-format => 'fasta', file => ">$fasta_file");
    my $q_out = Bio::SeqIO->new(-format => 'qual', file => ">$qual_file");

    my $fq_in =  Genome::Model::Tools::FastQual::FastqReader->create (
	file => $self->fastq_file,
	);
    while (my $seq = $fq_in->next) {
	my $seq_obj = Bio::Seq->new(-display_id => $seq->{id}, -seq => $seq->{seq});
	$f_out->write_seq($seq_obj);
	my @sanger_qual;
	for my $i (0..length($seq->{qual}) - 1) {
            #converting sanger qual values to phred ..
	    push @sanger_qual, (ord(substr($seq->{qual}, $i, 1)) - 33);
	}
	my $qual_obj = Bio::Seq::Quality->new(-display_id => $seq->{id}, -seq => $seq->{seq}, -qual => \@sanger_qual);
	$q_out->write_seq($qual_obj);
    }

    unlink $fasta_file.'.gz';
    unlink $qual_file.'.gz';

    if (system("gzip $fasta_file $qual_file")) {
	$self->error_message("Failed to zip files: $fasta_file $qual_file");
	return;
    }

    return 1;
}

1;
