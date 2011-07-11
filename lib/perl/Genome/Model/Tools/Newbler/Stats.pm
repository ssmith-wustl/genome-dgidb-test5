package Genome::Model::Tools::Newbler::Stats;

use strict;
use warnings;

use Genome;
use Data::Dumper;

class Genome::Model::Tools::Newbler::Stats {
    is => 'Genome::Model::Tools::Newbler',
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
    ],
};

sub help_brief {
    'Tools to run stats for soap assemblies'
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt newbler stats --assembly-directory /gscmnt/111/soap_assembly
EOS
}

sub help_detail {
    return <<EOS
Tool to run stats for newbler assemblies.
EOS
}

sub execute {
    my $self = shift;

    #contigs/supercontigs lengths, q20 consensus, etc
    my $contig_stats;
    unless ( $contig_stats = $self->_contigs_stats ) {
        $self->error_message( "Failed to generate contig stats" );
        return;
    }
    #rank contigs by lengths into tiers
    my ( $t1, $t2 );
    unless ( ($t1, $t2) = $self->_tier_values ) {
        $self->error_message( "Failed to resolve tier values" );
        return;
    }

    my $stats;
    unless ( $stats = $self->_simple_read_stats($contig_stats->{total_contig_length}) ) {
        $self->error_message( "Failed to generate simple read stats" );
        return;
    }

    foreach my $type ('contig', 'supercontig') {
        unless ( $stats .= $self->_contiguity_stats( $contig_stats, $type, $t1, $t2 ) ) {
            $self->error_message( "Failed to generate $type contiguity stats" );
            return;
        }
    };

    unless( $stats .= $self->_genome_contents_stats ) {
        $self->error_message( "Failed to generate genome contents stats" );
        return;
    }

    unlink $self->stats_file;
    my $fh = Genome::Sys->open_file_for_writing( $self->stats_file );

    $fh->print( $stats );
    $fh->close;

    print $stats;

    return 1;
}

sub _simple_read_stats {
    my ( $self, $total_contig_length ) = @_;

    my ( $reads, $bases, $q20_bases ) = $self->_get_input_read_and_qual_counts;

    my $avg_read_length = int( $bases / $reads );

    my $avg_q20_bases_per_read = int ( $q20_bases / $reads );

    my $assembled_reads = $self->_get_reads_assembled_stats;

    my $unplaced_reads = $reads - $assembled_reads;

    my $chaff_rate = sprintf("%.2f", $unplaced_reads * 100 / $reads + 0.5 );
    
    my $q20_redundancy = int ( $q20_bases / $total_contig_length );

    my $text = "*** SIMPLE READ STATS ***\n".
	       "Total input reads: $reads\n".
	       "Total input bases: $bases bp\n".
	       "Total Q20 bases: $q20_bases bp\n".
	       "Average Q20 bases per read: $avg_q20_bases_per_read bp\n".
	       "Average read length: $avg_read_length bp\n".
	       "Placed reads: $assembled_reads\n".
	       "Unplaced reads: $unplaced_reads\n".
	       "Chaff rate: $chaff_rate\n".
	       "Q20 base redundancy: $q20_redundancy\n\n";
    return $text;
}

sub _get_input_read_and_qual_counts {
    my $self = shift;

    my ( $reads, $bases, $q20_bases ) = 0;

    for my $file ( $self->input_fastq_files ) { #dies if not input fastq
        my $io = Genome::Model::Tools::Sx::FastqReader->create( file => $file );
        while ( my $seq = $io->read ) {
            $reads++;
            $bases += length $seq->{seq};
            my @quals = map { ord($_) - 33 } split('', $seq->{qual});
            for my $qual ( @quals ) {
                $q20_bases++ if $qual >= 20;
            }
        }
    }
    return $reads, $bases, $q20_bases;
}

sub _get_reads_assembled_stats {
    my $self = shift;

    unless( -s $self->newb_metrics_file ) {
        $self->error_message( "Failed to find newbler read stats file: ".$self->newb_metrics_file );
        return;
    }

    my $assembled_reads;
    my $fh = Genome::Sys->open_file_for_reading( $self->newb_metrics_file );
    while ( my $line = $fh->getline ) {
        if ( ($assembled_reads) = $line =~ /\s+numberAssembled\s+\=\s+(\d+)/ ) {
            last;
        }
    }
    $fh->close;

    if ( not $assembled_reads ) {
        $self->error_message( "Failed to get assembled reads from metrics file.  Expected a line like this: 'numberAssembled = 3200' in file but did't find one" );
        return;
    }

    return $assembled_reads;
}

sub _tier_values {
    my $self = shift;
    my $t1 = 0;
    my $t2 = 0;
    unless ( -s $self->contigs_bases_file ) {
        $self->error_message( "Failed to find contigs.bases file to estimate tier values: ".$self->contigs_bases_file );
        return;
    }
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

sub _contigs_stats {
    my $self = shift;
    my $counts = {};
    unless( -s $self->contigs_quals_file ) {
        $self->error_message( "Failed to find contigs.qual file: ".$self->contigs_quals_file );
        return;
    }
    my $io = Bio::SeqIO->new( -format => 'qual', -file => $self->contigs_quals_file );
    while ( my $seq = $io->next_seq ) {
	$counts->{total_contig_number}++;
	my ($supercontig_number, $contig_number) = $seq->primary_id =~ /Contig(\d+)\.(\d+)/i;
	$contig_number = $supercontig_number.'.'.$contig_number;
        my $contig_length = scalar @{$seq->qual};
	$counts->{total_contig_length} += $contig_length;
	$counts->{contig}->{$contig_number}->{bases} = $contig_length;
	$counts->{supercontig}->{$supercontig_number}->{bases} += $contig_length;
        for my $base ( @{$seq->qual} ) {
            if ( $base >= 20 ) {
                $counts->{contig}->{$contig_number}->{q20_bases}++;
                $counts->{supercontig}->{$supercontig_number}->{q20_bases}++;
            }
        }
    }
    return $counts;
}

sub _contiguity_stats {
    my ($self, $counts, $type, $t1, $t2) = @_;

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

    foreach my $c (sort {$counts->{$type}->{$b}->{bases} <=> $counts->{$type}->{$a}->{bases}} keys %{$counts->{$type}}) {
	$total_contig_number++;
	$total_q20_bases += $counts->{$type}->{$c}->{q20_bases};
	$cumulative_length += $counts->{$type}->{$c}->{bases};

	if ($counts->{$type}->{$c}->{bases} > $major_contig_length) {
	    $major_contig_bases += $counts->{$type}->{$c}->{bases};
	    $major_contig_q20_bases += $counts->{$type}->{$c}->{q20_bases};
	    $major_contig_number++;
	}
	if ($not_reached_n50) {
	    $n50_contig_number++;
	    if ($cumulative_length >= ($counts->{total_contig_length} * 0.50)) {
		$n50_contig_length = $counts->{$type}->{$c}->{bases};
		$not_reached_n50 = 0;
	    }
	}
	if ($counts->{$type}->{$c}->{bases} > $maximum_contig_length) {
	    $maximum_contig_length = $counts->{$type}->{$c}->{bases};
	}
	#TIER 1
	if ($total_t1_bases < $t1) {
	    $total_t1_bases += $counts->{$type}->{$c}->{bases};
	    $total_t1_q20_bases += $counts->{$type}->{$c}->{q20_bases};
	    if ($t1_not_reached_n50) {
		$t1_n50_contig_number++;
		if ($cumulative_length >= ($t1 * 0.50)) {
		    $t1_n50_contig_length = $counts->{$type}->{$c}->{bases};
		    $t1_not_reached_n50 = 0;
		}
	    }
	    $t1_count++;
	    if ($t1_max_length == 0) {
		$t1_max_length = $counts->{$type}->{$c}->{bases};
	    }
	}
	#TIER 2
	elsif ($total_t2_bases < $t2) {
	    $total_t2_bases += $counts->{$type}->{$c}->{bases};
	    $total_t2_q20_bases += $counts->{$type}->{$c}->{q20_bases};
	    if ($t2_not_reached_n50) {
		$t2_n50_contig_number++;
		if ($cumulative_length >= ($t2 * 0.50)) {
		    $t2_n50_contig_length = $counts->{$type}->{$c}->{bases};
		    $t2_not_reached_n50 = 0;
		}
	    }
	    $t2_count++;
	    if ($t2_max_length == 0) {
		$t2_max_length = $counts->{$type}->{$c}->{bases};
	    }
	}
	#TIER 3
	else {
	    $total_t3_bases += $counts->{$type}->{$c}->{bases};
	    $total_t3_q20_bases += $counts->{$type}->{$c}->{q20_bases};
	    if ($t3_not_reached_n50) {
		$t3_n50_contig_number++;
		if ($cumulative_length >= ($t3 * 0.50)) {
		    $t3_n50_contig_length = $counts->{$type}->{$c}->{bases};
		    $t3_not_reached_n50 = 0;
		}
	    }
	    $t3_count++;
	    if ($t3_max_length == 0) {
		$t3_max_length = $counts->{$type}->{$c}->{bases};
	    }
	}

	#FOR SUPERCONTIGS CONTIGUITY METRICS .. calculated number of contigs > 1M, 250K, 100-250K etc
	if ($counts->{$type}->{$c}->{bases} > 1000000) {
	    $larger_than_1M++;
	}
	elsif ($counts->{$type}->{$c}->{bases} > 250000) {
	    $larger_than_250K++;
	}
	elsif ($counts->{$type}->{$c}->{bases} > 100000) {
	    $larger_than_100K++;
	}
	elsif ($counts->{$type}->{$c}->{bases} > 10000) {
	    $larger_than_10K++;
	}
	elsif ($counts->{$type}->{$c}->{bases} > 5000) {
	    $larger_than_5K++;
	}
	elsif ($counts->{$type}->{$c}->{bases} > 2000) {
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
    foreach my $c (sort {$counts->{$type}->{$b}->{bases} <=> $counts->{$type}->{$a}->{bases}} keys %{$counts->{$type}}) {
	next unless $counts->{$type}->{$c}->{bases} > $major_contig_length;
	$n50_cumulative_length += $counts->{$type}->{$c}->{bases};
	if ($not_reached_major_n50) {
	    $n50_major_contig_number++;
	    if ($n50_cumulative_length >= $major_contig_bases * 0.50) {
		$not_reached_major_n50 = 0;
		$n50_major_contig_length = $counts->{$type}->{$c}->{bases};
	    }
	}
    }

    my $average_contig_length = int ($cumulative_length / $total_contig_number + 0.50);
    my $average_major_contig_length = ($major_contig_number > 0) ?
	int ($major_contig_bases / $major_contig_number + 0.50) : 0;
    my $average_t1_contig_length = ($t1_count > 0) ? int ($total_t1_bases/$t1_count + 0.5) : 0;
    my $average_t2_contig_length = ($t2_count > 0) ? int ($total_t2_bases/$t2_count + 0.5) : 0;
    my $average_t3_contig_length = ($t3_count > 0) ? int ($total_t3_bases/$t3_count + 0.5) : 0;

    #q20 ratios
    my $q20_ratio = ( $total_q20_bases > 0 ) ?
        sprintf ("%.1f", $total_q20_bases * 100 / $cumulative_length ): 0;
    my $t1_q20_ratio = ( $total_t1_q20_bases > 0 ) ?
        sprintf ("%0.1f", $total_t1_q20_bases * 100 / $total_t1_bases) : 0;
    my $t2_q20_ratio = ( $total_t2_q20_bases > 0 ) ?
        sprintf ("%0.1f", $total_t2_q20_bases * 100 / $total_t2_bases) : 0;
    my $t3_q20_ratio = ( $total_t3_q20_bases > 0 ) ?
        sprintf ("%0.1f", $total_t3_q20_bases * 100 / $total_t3_bases) : 0;

    my $major_contig_q20_ratio = ( $major_contig_q20_bases > 0 ) ?
        sprintf( "%.1f", $major_contig_q20_bases * 100 / $major_contig_bases ) : 0;

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

sub parse_contigs_bases_file {
    my $self = shift;
    my %counts;
    unless ( -s $self->contigs_bases_file ) {
        $self->error_message( "Failed to find contigs.bases file" );
        return;
    }
    my $io = Bio::SeqIO->new( -format => 'fasta', -file => $self->contigs_bases_file );
    while ( my $seq = $io->next_seq ) {
        my $contig_length = length $seq->seq;
        $counts{total_contig_bases} += $contig_length;
        $counts{five_kb_contigs_lengths} += $contig_length if $contig_length >= 5000;
        my @tmp = split( '', $seq->seq );
        for my $base ( @tmp ) {
            if ( $base =~ /[gc]/i ) {
                $counts{gc_count}++;
            } elsif ( $base =~ /[at]/i ) {
                $counts{at_count}++;
            } elsif ( $base =~ /[xn]/i ) {
                $counts{nx_count}++;
            } else {
                $self->error_message( "Found none ACTGNX bases in consensus in contig ".$seq->primary_id."\n".$seq->seq );
                return;
            }
        }
    }
    return \%counts;
}

sub _genome_contents_stats {
    my $self = shift;

    my $counts;
    unless ( $counts = $self->parse_contigs_bases_file ) {
        $self->error_message( "Failed to get contigs consensus stats" );
        return;
    }

    my $total_contig_length = $counts->{total_contig_bases};
    
    #GC/AT ratio stats
    my $gc_count = ( exists $counts->{gc_count} ) ? $counts->{gc_count} : 0;
    my $gc_ratio = ( $gc_count ) ? sprintf( "%.1f", $gc_count * 100 / $total_contig_length + 0.5 ) : 0; 
    my $at_count = ( exists $counts->{at_count} ) ? $counts->{at_count} : 0;
    my $at_ratio = ( $at_count ) ? sprintf( "%.1f", $at_count * 100 / $total_contig_length + 0.5 ) : 0;
    my $nx_count = ( exists $counts->{nx_count} ) ? $counts->{nx_count} : 0;
    my $nx_ratio = ( $nx_count ) ? sprintf( "%.1f", $nx_count * 100 / $total_contig_length + 0.5 ) : 0;

    my $stats = "\n*** Genome Contents ***\n".
                "Total GC count: $gc_count, (".$gc_ratio."%)\n".
                "Total AT count: $at_count, (".$at_ratio."%)\n".
                "Total NX count: $nx_count, (".$nx_ratio."%)\n".
                "Total: $total_contig_length\n\n";

    #greater than 5kb stats
    my $five_kb_contigs_lengths = ( exists $counts->{five_kb_contigs_lengths} ) ?
        $counts->{five_kb_contigs_lengths} : 0;

    my $five_kb_ratio = ( $five_kb_contigs_lengths ) ?
        int ( $five_kb_contigs_lengths * 100 / $total_contig_length ) : 0;

    $stats .= "\n*** 5 Kb and Greater Contigs Info ***\n".
              "Total lengths of all contigs: $total_contig_length\n".
              "Total lengths of contigs 5 Kb and greater: $five_kb_contigs_lengths\n".
              "Percentage of genome: ".$five_kb_ratio."%\n\n";

    return $stats;
}

1;
