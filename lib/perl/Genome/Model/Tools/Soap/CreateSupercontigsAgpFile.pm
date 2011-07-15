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
        min_contig_length => {
            is => 'Number',
            doc => 'Minimum contig length to process',
        },	
    ],
};

sub help_brief {
    'Tool to create supercontigs.agp file from soap created scaffold fasta file';
}

sub help_detail {
    return <<"EOS"
gmt soap create-supercontigs-agp-file --assembly-directory /gscmnt/111/soap_assembly --min-contig-length 200
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
    
    unless( -s $self->assembly_scaffold_sequence_file ) {
        $self->error_message("Failed to find soap scaffold sequence file: ".$self->assembly_scaffold_sequence_file);
        return;
    }

    unlink $self->supercontigs_agp_file;
    my $fh = Genome::Sys->open_file_for_writing( $self->supercontigs_agp_file );

    my $io = Bio::SeqIO->new( -format => 'fasta', -file => $self->assembly_scaffold_sequence_file );

    my $scaffold_number = 0;

    while (my $seq = $io->next_seq) {
        #remove lead/trail-ing Ns
        my $supercontig = $seq->seq;
        $supercontig =~ s/^N+//;
        $supercontig =~ s/N+$//;

        #skip if less than min contig length
        next unless length $supercontig >= $self->min_contig_length;

	my $scaffold_name = 'Contig'.$scaffold_number++;
	my @bases = split (/N+/i, $supercontig);
	my @gaps = split (/[ACTG]+/i, $supercontig);

	shift @gaps; #empty string from split .. unless seq starts with Ns in which case it's just thrown out

	my $start_pos = 0;
	my $stop_pos = 0;
	my $fragment_order = 0;
	my $contig_order = 0;
	my $prev_start = 0;

	for (my $i = 0; $i < scalar @bases; $i++) {
            #if first or last string and < min length skip .. no need process gap info
            next if $i == 0 and length $bases[$i] < $self->min_contig_length;
            next if $i == $#bases and length $bases[$i] < $self->min_contig_length;

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
