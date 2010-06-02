package Genome::Model::Tools::Assembly::CreateOutputFiles::InputFromFastq;

use strict;
use warnings;

use Genome;
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

sub help_synopsis {
    my $self = shift;
    return <<EOS
EOS
}

sub help_detail {
    return <<EOS
EOS
}

sub execute {
    my $self = shift;

    my $root_name = File::Basename::basename($self->fastq_file);
    $root_name =~ s/\.fastq//;

    my $fasta_file = $self->directory.'/edit_dir/'.$root_name.'.fasta';
    my $qual_file = $self->directory.'/edit_dir/'.$root_name.'.fasta.qual';

    my $f_out = Bio::SeqIO->new(-format => 'fasta', file => ">$fasta_file");
    my $q_out = Bio::SeqIO->new(-format => 'qual', file => ">$qual_file");

    my $fq_in = Bio::SeqIO->new(-format => 'fastq', -file => $self->fastq_file);
    while (my $seq = $fq_in->next_seq) {
	$f_out->write_seq($seq); #write fasta
	#need to subtract 31 from velvet qual to match sanger qual
	my @new_qual = map {$_ - 31} @{$seq->qual};
	$seq->qual(\@new_qual);
	$q_out->write_seq($seq);
    }

    #if zipped version of files exist remove them first

    unlink $fasta_file.'.gz';
    unlink $qual_file.'.gz';

    if (system("gzip $fasta_file $qual_file")) {
	$self->error_message("Failed to zip files: $fasta_file $qual_file");
	return;
    }

    return 1;
}

1;
