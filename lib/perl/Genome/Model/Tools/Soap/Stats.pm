package Genome::Model::Tools::Soap::Stats;

use strict;
use warnings;
use Genome::Model::Tools::FastQual::FastqReader;

use Genome;
use Data::Dumper;

class Genome::Model::Tools::Soap::Stats {
    is => 'Genome::Model::Tools::Soap',
    has => [
	assembly_directory => {
	    is => 'Text',
	    doc => 'Path to soap assembly',
	},
	first_tier => {
	    is => 'Number',
	    doc => 'First tier value',
	    is_optional => 1,
	},
	second_tier => {
	    is => 'Number',
	    doc => 'Second tier value',
	    is_optional => 1,
	},
	major_contig_length => {
	    is => 'Number',
	    is_optional => 1,
	    default_value => 300,
	    doc => 'Cutoff value for major contig length',
	},
	output_file => {
	    is => 'Text',
	    is_optional => 1,
	    doc => 'Stats output file',
	},
	remove_output_files => {
	    is => 'Boolean',
	    is_optional => 1,
	    doc => 'Option to remove files created to derive stats',
	}
    ],
};

sub help_brief {
    'Tools to run stats for soap assemblies'
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt soap stats --assembly-directory /gscmnt/111/soap_assembly
EOS
}

sub help_detail {
    return <<EOS
Tool to run stats for soap assemblies.
EOS
}

sub execute {
    my $self = shift;

    #create edit_dir
    unless ( $self->create_edit_dir ) {
	$self->error_message("Failed to create edit_dir");
	return;
    }

    #get contig/supercontig contig lengths
    my $counts = $self->parse_contigs_bases_file;

    #TODO - just passing in empty hash ref for q20 values since soap doesn't evaluate qual
         #-fix so this is not needed
    my $q20_counts = {};

    my ($t1, $t2) = $self->_resolve_tier_values();

    my $text = $self->_get_simple_read_stats();

    foreach my $type ('contig', 'supercontig') {
	$text .= $self->create_contiguity_stats ($counts, $q20_counts, $type, $t1, $t2);
    };

    my $stats_file = ($self->output_file) ? $self->output_file : $self->stats_file;
    unlink $stats_file if -e $stats_file;
    my $fh = Genome::Sys->open_file_for_writing($stats_file);
    $fh->print($text);
    $fh->close;

    print $text;

    #remove files if this is run from report
    if ( $self->remove_output_files ) {
	unlink $self->contigs_bases_file;
    }
    
    return 1;
}

sub _get_simple_read_stats {
    my $self = shift;

    my ($read_count, $base_count) = $self->_get_input_read_and_bases_counts();

    my $avg_read_length = int($base_count / $read_count);
    my $text = "*** SIMPLE READ STATS ***\n".
	       "Total input reads: $read_count\n".
	       "Total input bases: $base_count bp\n".
	       "Total Q20 bases: NA bp\n".
	       "Average Q20 bases per read: NA bp\n".
	       "Average read length: $avg_read_length bp\n".
	       "Placed reads: NA\n".
	       "(reads in scaffolds: NA)\n".
	       "(unique reads: NA)\n".
	       "(duplicate reads: NA)\n".
	       "Unplaced reads: NA\n".
	       "Chaff rate: NA\n".
	       "Q20 base redundancy: NA\n\n";
    return $text;
}

sub _resolve_tier_values {
    my $self = shift;
    my $t1 = 0;
    my $t2 = 0;
    if ($self->first_tier and $self->second_tier) {
	$t1 = $self->first_tier;
	$t2 = $self->second_tier;
    }
    else {
	my $est_genome_size = -s $self->contigs_bases_file;

	$t1 = int ($est_genome_size * 0.2);
	$t2 = int ($est_genome_size * 0.2);
    }
    return ($t1, $t2);
}

sub parse_contigs_bases_file {
    my $self = shift;

    my $counts = {};
    my ($supercontig_number, $contig_number);

    my $contigs_bases_file = $self->contigs_bases_file;

    unless ( -s $contigs_bases_file ) {#create it
	my $create =  Genome::Model::Tools::Soap::CreateContigsBasesFile->create(
	    assembly_directory => $self->assembly_directory,
	    );
	unless ( $create->execute ) {
	    $self->error_message("Failed to create contigs.bases file");
	    return;
	}
    }

    my $io = Bio::SeqIO->new(-format => 'fasta', -file => $contigs_bases_file);
    while (my $seq = $io->next_seq) {
	$counts->{total_contig_number}++;
	($supercontig_number, $contig_number) = $seq->primary_id =~ /Contig(\d+)\.(\d+)/i;
	$contig_number = $supercontig_number.'.'.$contig_number;
	$counts->{total_contig_length} += length $seq->seq;
	$counts->{contig}->{$contig_number} = length $seq->seq;
	$counts->{supercontig}->{$supercontig_number} += length $seq->seq;
    }

    return $counts;
}

sub create_contiguity_stats {
    my ($self, $counts, $q20_counts, $type, $t1, $t2) = @_;

    #TYPE IS CONTIG OR SUPERCONTIG
    my $major_contig_length = $self->major_contig_length;
    my $t3 = $counts->{total_contig_length} - ($t1 + $t2);
    #TOTAL CONTIG VARIABLES
    my $total_contig_number = 0;    my $cumulative_length = 0;
    my $maximum_contig_length = 0;  my $major_contig_number = 0;
    my $major_contig_bases = 0;     my $major_contig_q20_bases = 0;
    my $n50_contig_number = 0;      my $n50_contig_length = 0;
    my $not_reached_n50 = 1;        my $total_q20_bases = 0;
    #TIER 1 VARIABLES
    my $total_t1_bases = 0;         my $total_t1_q20_bases = 0;
    my $t1_n50_contig_number = 0;   my $t1_n50_contig_length = 0;
    my $t1_not_reached_n50 = 1;     my $t1_max_length = 0;
    my $t1_count = 0;
    #TIER 2 VARIABLES
    my $total_t2_bases = 0;         my $total_t2_q20_bases = 0;
    my $t2_n50_contig_number = 0;   my $t2_n50_contig_length = 0;
    my $t2_not_reached_n50 = 1;     my $t2_max_length = 0;
    my $t2_count = 0;
    #TIER 3 VARIABLES
    my $total_t3_bases = 0;         my $total_t3_q20_bases = 0;
    my $t3_n50_contig_number = 0;   my $t3_n50_contig_length = 0;
    my $t3_not_reached_n50 = 1;     my $t3_max_length = 0;
    my $t3_count = 0;
    #ASSESS CONTIG / SUPERCONTIG SIZE VARIABLES
    my $larger_than_1M = 0;         my $larger_than_250K = 0;
    my $larger_than_100K = 0;       my $larger_than_10K = 0;
    my $larger_than_5K = 0;         my $larger_than_2K = 0;
    my $larger_than_0K = 0;

    foreach my $c (sort {$counts->{$type}->{$b} <=> $counts->{$type}->{$a}} keys %{$counts->{$type}}) {
	$total_contig_number++;
	$total_q20_bases += $q20_counts->{$c}->{q20_bases} if exists $q20_counts->{$c};
	$cumulative_length += $counts->{$type}->{$c};

	if ($counts->{$type}->{$c} > $major_contig_length) {
	    $major_contig_bases += $counts->{$type}->{$c};
	    $major_contig_q20_bases += $q20_counts->{$c}->{q20_bases}if exists $q20_counts->{$c};
	    $major_contig_number++;
	}
	if ($not_reached_n50) {
	    $n50_contig_number++;
	    if ($cumulative_length >= ($counts->{total_contig_length} * 0.50)) {
		$n50_contig_length = $counts->{$type}->{$c};
		$not_reached_n50 = 0;
	    }
	}
	if ($counts->{$type}->{$c} > $maximum_contig_length) {
	    $maximum_contig_length = $counts->{$type}->{$c};
	}
	#TIER 1
	if ($total_t1_bases < $t1) {
	    $total_t1_bases += $counts->{$type}->{$c};
	    $total_t1_q20_bases += $q20_counts->{$c}->{q20_bases} if exists $q20_counts->{$c};
	    if ($t1_not_reached_n50) {
		$t1_n50_contig_number++;
		if ($cumulative_length >= ($t1 * 0.50)) {
		    $t1_n50_contig_length = $counts->{$type}->{$c};
		    $t1_not_reached_n50 = 0;
		}
	    }
	    $t1_count++;
	    if ($t1_max_length == 0) {
		$t1_max_length = $counts->{$type}->{$c}
	    }
	}
	#TIER 2
	elsif ($total_t2_bases < $t2) {
	    $total_t2_bases += $counts->{$type}->{$c};
	    $total_t2_q20_bases += $q20_counts->{$c}->{q20_bases} if exists $q20_counts->{$c};
	    if ($t2_not_reached_n50) {
		$t2_n50_contig_number++;
		if ($cumulative_length >= ($t2 * 0.50)) {
		    $t2_n50_contig_length = $counts->{$type}->{$c};
		    $t2_not_reached_n50 = 0;
		}
	    }
	    $t2_count++;
	    if ($t2_max_length == 0) {
		$t2_max_length = $counts->{$type}->{$c}
	    }
	}
	#TIER 3
	else {
	    $total_t3_bases += $counts->{$type}->{$c};
	    $total_t3_q20_bases += $q20_counts->{$c}->{q20_bases} if exists $q20_counts->{$c};
	    if ($t3_not_reached_n50) {
		$t3_n50_contig_number++;
		if ($cumulative_length >= ($t3 * 0.50)) {
		    $t3_n50_contig_length = $counts->{$type}->{$c};
		    $t3_not_reached_n50 = 0;
		}
	    }
	    $t3_count++;
	    if ($t3_max_length == 0) {
		$t3_max_length = $counts->{$type}->{$c}
	    }
	}

	#FOR SUPERCONTIGS CONTIGUITY METRICS .. calculated number of contigs > 1M, 250K, 100-250K etc
	if ($counts->{$type}->{$c} > 1000000) {
	    $larger_than_1M++;
	}
	elsif ($counts->{$type}->{$c} > 250000) {
	    $larger_than_250K++;
	}
	elsif ($counts->{$type}->{$c} > 100000) {
	    $larger_than_100K++;
	}
	elsif ($counts->{$type}->{$c} > 10000) {
	    $larger_than_10K++;
	}
	elsif ($counts->{$type}->{$c} > 5000) {
	    $larger_than_5K++;
	}
	elsif ($counts->{$type}->{$c} > 2000) {
	    $larger_than_2K++;
	}
	else {
	    $larger_than_0K++;
	}
    }
    #NEED TO ITERATE THROUGH COUNTS HASH AGAGIN FOR N50 SPECIFIC STATS
    #TODO - This can be avoided by calculating and storing total major-contigs-bases
    #in counts hash
    my $n50_cumulative_length = 0; my $n50_major_contig_number = 0;
    my $not_reached_major_n50 = 1; my $n50_major_contig_length = 0;
    foreach my $c (sort {$counts->{$type}->{$b} <=> $counts->{$type}->{$a}} keys %{$counts->{$type}}) {
	next unless $counts->{$type}->{$c} > $major_contig_length;
	$n50_cumulative_length += $counts->{$type}->{$c};
	if ($not_reached_major_n50) {
	    $n50_major_contig_number++;
	    if ($n50_cumulative_length >= $major_contig_bases * 0.50) {
		$not_reached_major_n50 = 0;
		$n50_major_contig_length = $counts->{$type}->{$c};
	    }
	}
    }

    my $average_contig_length = int ($cumulative_length / $total_contig_number + 0.50);
    my $average_major_contig_length = ($major_contig_number > 0) ?
	int ($major_contig_bases / $major_contig_number + 0.50) : 0;
    my $average_t1_contig_length = ($t1_count > 0) ? int ($total_t1_bases/$t1_count + 0.5) : 0;
    my $average_t2_contig_length = ($t2_count > 0) ? int ($total_t2_bases/$t2_count + 0.5) : 0;
    my $average_t3_contig_length = ($t3_count > 0) ? int ($total_t3_bases/$t3_count + 0.5) : 0;

    my $q20_ratio = 0;                  my $t1_q20_ratio = 0;
    my $t2_q20_ratio = 0;               my $t3_q20_ratio = 0;
    my $major_contig_q20_ratio = 0;

    $total_q20_bases = 'NA';
    $q20_ratio = 'NA';
    $major_contig_q20_bases = 'NA';
    $major_contig_q20_ratio = 'NA';
    $total_t1_q20_bases = 'NA';
    $total_t2_q20_bases = 'NA';
    $total_t3_q20_bases = 'NA';
    $t1_q20_ratio = 'NA';
    $t2_q20_ratio = 'NA';
    $t3_q20_ratio = 'NA';

    my $type_name = ucfirst $type;
    my $text = "\n*** Contiguity: $type_name ***\n".
	       "Total $type_name number: $total_contig_number\n".
	       "Total $type_name bases: $cumulative_length bp\n".
	       "Total Q20 bases: $total_q20_bases bp\n".
	       "Q20 bases %: $q20_ratio %\n".
	       "Average $type_name length: $average_contig_length bp\n".
	       "Maximum $type_name length: $maximum_contig_length bp\n".
	       "N50 $type_name length: $n50_contig_length bp\n".
	       "N50 contig number: $n50_contig_number\n".
	       "\n".
	       "Major $type_name (> $major_contig_length bp) number: $major_contig_number\n".
	       "Major $type_name bases: $major_contig_bases bp\n".
	       "Major_$type_name avg contig length: $average_major_contig_length bp\n".
	       "Major_$type_name Q20 bases: $major_contig_q20_bases bp\n".
	       "Major_$type_name Q20 base percent: $major_contig_q20_ratio %\n".
	       "Major_$type_name N50 contig length: $n50_major_contig_length bp\n".
	       "Major_$type_name N50 contig number: $n50_major_contig_number\n".
	       "\n";
    if ($type eq 'supercontig') {
	$text .= "Scaffolds > 1M: $larger_than_1M\n".
	         "Scaffold 250K--1M: $larger_than_250K\n".
		 "Scaffold 100K--250K: $larger_than_100K\n".
		 "Scaffold 10--100K: $larger_than_10K\n".
		 "Scaffold 5--10K: $larger_than_5K\n".
		 "Scaffold 2--5K: $larger_than_2K\n".
		 "Scaffold 0--2K: $larger_than_0K\n\n";
    }

    $text .= "Top tier (up to $t1 bp): \n".
	     "  Contig number: $t1_count\n".
	     "  Average length: $average_t1_contig_length bp\n".
	     "  Longest length: $t1_max_length bp\n".
	     "  Contig bases in this tier: $total_t1_bases bp\n".
	     "  Q20 bases in this tier: $total_t1_q20_bases bp\n".
	     "  Q20 base percentage: $t1_q20_ratio %\n".
	     "  Top tier N50 contig length: $t1_n50_contig_length bp\n".
	     "  Top tier N50 contig number: $t1_n50_contig_number\n".
	     "Middle tier ($t1 bp -- ".($t1 + $t2)." bp): \n".
	     "  Contig number: $t2_count\n".
	     "  Average length: $average_t2_contig_length bp\n".
	     "  Longest length: $t2_max_length bp\n".
	     "  Contig bases in this tier: $total_t2_bases bp\n".
	     "  Q20 bases in this tier: $total_t2_q20_bases bp\n".
	     "  Q20 base percentage: $t2_q20_ratio %\n".
	     "  Middle tier N50 contig length: $t2_n50_contig_length bp\n".
	     "  Middle tier N50 contig number: $t2_n50_contig_number\n".
	     "Bottom tier (".($t1 + $t2)." bp -- end): \n".
	     "  Contig number: $t3_count\n".
	     "  Average length: $average_t3_contig_length bp\n".
	     "  Longest length: $t3_max_length bp\n".
	     "  Contig bases in this tier: $total_t3_bases bp\n".
	     "  Q20 bases in this tier: $total_t3_q20_bases bp\n".
	     "  Q20 base percentage: $t3_q20_ratio %\n".
	     "  Bottom tier N50 contig length: $t3_n50_contig_length bp\n".
	     "  Bottom tier N50 contig number: $t3_n50_contig_number\n".
	     "\n";
    
    return $text;
}

sub _get_input_read_and_bases_counts {
    my $self = shift;
    my $read_count = 0;
    my $base_count = 0;

    for my $fastq( @{$self->assembly_input_fastq_files} ) {
	my $io = Genome::Model::Tools::FastQual::FastqReader->create(file => $fastq);
	while (my $seq = $io->next) { #just getting number of reads
	    $read_count++;
	    $base_count += length $seq->{seq};
	}
    }
    return $read_count, $base_count;
}

1;
