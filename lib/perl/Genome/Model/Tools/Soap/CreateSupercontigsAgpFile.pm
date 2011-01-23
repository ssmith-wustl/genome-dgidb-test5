package Genome::Model::Tools::Soap::CreateSupercontigsAgpFile;

use strict;
use warnings;

use Genome;
use Bio::SeqIO;
use Data::Dumper;

class Genome::Model::Tools::Soap::CreateSupercontigsAgpFile {
    is => 'Genome::Model::Tools::Soap',
    has => [
        assembly_directory => {
            is => 'Text',
            doc => 'Soap assembly directory',
        },
	output_file => {
	    is => 'Text',
	    doc => 'User supplied output file name',
	    is_optional => 1,
	},
        scaffold_sequence_file => {
            is => 'Text',
	    is_optional => 1,
            doc => 'Soap created scaffolds fasta file',
        },	
    ],
};

sub help_brief {
    'Tool to create supercontigs.agp file from soap created scaffold fasta file';
}

sub help_detail {
    return <<"EOS"
gmt soap create-supercontigs-agp-file --scaffold-sequence-file /gscmnt/111/soap_assembly/61EFS.cafSeq --assembly-directory /gscmnt/111/soap_assembly
EOS
}

sub execute {
    my $self = shift;

    unless ( $self->create_edit_dir ) {
	$self->error_message("Failed to create edit_dir");
	return;
    }

    unless (-d $self->assembly_directory) {
        $self->error_message("Failed to find assembly directory: ".$self->assembly_directory);
        return;
    }

    my $scaf_seq_file = ( $self->scaffold_sequence_file ) ? $self->scaffold_sequence_file : $self->assembly_scaffold_sequence_file;

    my $out_file = ($self->output_file) ? $self->output_file : $self->supercontigs_agp_file;

    unlink $out_file;
    my $fh = Genome::Sys->open_file_for_writing($out_file);

    my $io = Bio::SeqIO->new(-format => 'fasta', -file => $scaf_seq_file);

    my $scaffold_number = 0;

    while (my $seq = $io->next_seq) {

	my $scaffold_name = 'Contig'.$scaffold_number++;
	my @bases = split (/N+/i, $seq->seq);
	my @gaps = split (/[ACTG]+/i, $seq->seq);

	shift @gaps; #empty string from split .. unless seq starts with Ns in which case it's just thrown out

	my $start_pos = 0;
	my $stop_pos = 0;
	my $fragment_order = 0;
	my $contig_order = 0;
	my $prev_start = 0;

	for (my $i = 0; $i < scalar @bases; $i++) {

	    my $contig_name = $scaffold_name.'.'.++$contig_order;

	    #for sequences print:
	    #sctg    start   stop    order   W       contig name     1       length  +
	    #Contig1 1       380     1       W       Contig1.1       1       380     +
	    $start_pos = ($i > 0) ? $start_pos + (length $gaps[$i - 1]) : 1;
	    $stop_pos = $stop_pos + (length $bases[$i]);
	    $fh->print($scaffold_name."\t".$start_pos."\t".$stop_pos."\t".++$fragment_order."\tW\t".$contig_name."\t1\t".(length $bases[$i])."\t+"."\n");

	    #for gaps print:
	    #sctg    start   stop    order   N       length  fragment        yes
	    #Contig1 381     453     2       N       73      fragment        yes
	    last if $i == scalar @bases - 1; #just got last seq on scaf .. so should be no more gap ..ignore trailing NNNs if any
	    $start_pos = $start_pos + (length $bases[$i]);
	    $stop_pos = $stop_pos + (length $gaps[$i]);
	    $fh->print($scaffold_name."\t".$start_pos."\t".$stop_pos."\t".++$fragment_order."\tN\t".(length $gaps[$i])."\tfragment\tyes"."\n");
	}
    }

    $fh->close;

    return 1;
}

1;
