package Genome::Model::Tools::Oligo::PcrPrimers;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Oligo::PcrPrimers {
    is => 'Command',                    
    has => [ 
	     
	     fasta_file => {
	         type  =>  'String',
		 doc   =>  "provide the fasta file for the pcr primer design",
	     },
	     output_name => {
	         type  =>  'String',
		 doc   =>  "provide a root name for output files. Default set to chr:target_depth",
		 is_optional  => 1,
	     },
	     output_dir => {
	         type  =>  'String',
		 doc   =>  "provide the full path to where you want your output files. Default set to ./",
		 is_optional  => 1,
		 default => './',
	     },
	     target_depth => {
 	         type  =>  'String',
		 doc   =>  "bases to the target. Default will put the target in the center of the sequence",
		 is_optional  => 1,
	     },
	     primer_perimeter => {
 	         type  =>  'String',
		 doc   =>  "minimum distance from target for primers. Default is 30 bases either side of the target",
		 default => "30",
		 is_optional  => 1,
	     },
	        bp_id => {
	         type  =>  'String',
		 doc   =>  "This option can be used in place of target-depth. The target depth will be calcuated from the breakpoint id and fasta coordinates. Most useful if your target is not in the center of the sequence and or for indel targets.",
		 is_optional  => 1,
	     },
	      product_range => {
	         type  =>  'String',
		 doc   =>  "provide the range of sizes exceptable for your pcr product. Default set at 125-800",
		 is_optional  => 1,
	     },
	      product_opt_size => {
	         type  =>  'String',
		 doc   =>  "provide the optimal size for your pcr product. Default set at 400",
		 is_optional  => 1,
	     },
	      tm_min => {
	         type  =>  'String',
		 doc   =>  "provide the minimum tm for your pcr primers. Default set at 56",
		 is_optional  => 1,
	     },
	      tm_max => {
	         type  =>  'String',
		 doc   =>  "provide the maximum tm for your pcr primers. Default set at 70",
		 is_optional  => 1,
	     },
	      tm_opt => {
	         type  =>  'String',
		 doc   =>  "provide the optimal tm for your pcr primers. Default set at 63",
		 is_optional  => 1,
	     },
	      tm_max_diff => {
	         type  =>  'String',
		 doc   =>  "provide the maximum difference in tm between your pcr primers. Default set at 2",
		 is_optional  => 1,
	     },
	      product_tm_max => {
	         type  =>  'String',
		 doc   =>  "provide the maximum combined tm for your pcr primers. Default set at 85",
		 is_optional  => 1,
	     },
	      poly_nuc_max => {
	         type  =>  'String',
		 doc   =>  "provide the maximum length of mononucleopaired_primerse run of bases you'd like to see in your pcr primers. Default set at 3",
		 is_optional  => 1,
	     },
	      psize_max => {
	         type  =>  'String',
		 doc   =>  "provide the maximum length for your primers. Default set at 24",
		 is_optional  => 1,
	     },
	      psize_min => {
	         type  =>  'String',
		 doc   =>  "provide the minimum length for your primers. Default set at 18",
		 is_optional  => 1,
	     },
	      psize_opt => {
	         type  =>  'String',
		 doc   =>  "provide the optimal length for your primers. Default set at 22",
		 is_optional  => 1,
	     },
	      gc_max => {
	         type  =>  'String',
		 doc   =>  "provide the maximum percent GC content for your primers. Default set at 70",
		 is_optional  => 1,
	     },
	      gc_min => {
	         type  =>  'String',
		 doc   =>  "provide the minimum percent GC content for your primers. Default set at 30",
		 is_optional  => 1,
	     },
	      gc_opt => {
	         type  =>  'String',
		 doc   =>  "provide the optimal percent GC content for your primers. Default set at 50",
		 is_optional  => 1,
	     },
	      gc_clamp => {
	         type  =>  'String',
		 doc   =>  "provide the number of G's and/or C'c you'd like to have on the end of your primers. Default set to not stipulate",
		 is_optional  => 1,
	     },
	      return_pairs => {
	         type  =>  'String',
		 doc   =>  "provide the number primer pairs you'd like to see. Default set to 10",
		 is_optional  => 1,
	     },
	      p_pair_compl_any => {
	         type  =>  'String',
		 doc   =>  "provide the number for self-complementarity measures of the selected oligo. Default set to 4",
		 is_optional  => 1,
	     },
	      primer3_defaults => {
		 is => 'Boolean',
		 doc   =>  "Use this flag if you'd like to run primer3 without stipulating anything but the boundries. Default set as listed",
		 is_optional  => 1,
	     },
	      hspsepSmax => {
	         type  =>  'String',
		 doc   =>  "provide the hspsepSmax if your primers are to be on the same chromosome and the genomic distance between them is greater than 1000bp. Default set at 1000",
		 default => "1000",
		 is_optional  => 1,
	     },
	     filter_primers => {
	         type  =>  'String',
		 doc   =>  "provide primers sequences you'd like to filter out of the score file. If more than one place a comma between each; eg CTAGTTCTTGTGGAGCCCATTTATAG,ATCCTGGCTAACATGGTGAAAC",
		 is_optional  => 1,
	     },
	     mask_primers => {
	         type  =>  'String',
		 doc   =>  "provide primers sequences you'd like to screen out of the fasta file. If more than one place a comma between each; eg CTAGTTCTTGTGGAGCCCATTTATAG,ATCCTGGCTAACATGGTGAAAC",
		 is_optional  => 1,
	     },
	     mask_list => {
	         type  =>  'String',
		 doc   =>  "provide a list of bases you'd like masked in your fasta prior to picking primers. The list needs to be at least two coulmns with the first column being the chromosome and the second being the coordinate. Also, the fasta file needs to have the chromosome and coordinates in it. primers sequences you'd like to screen out of the fasta file. If more than one place a comma between each; eg CTAGTTCTTGTGGAGCCCATTTATAG,ATCCTGGCTAACATGGTGAAAC",
		 is_optional  => 1,
	     },
	     mask_dbsnps => {
		 is => 'Boolean',
		 doc   =>  "use this option if you'd like to mask your fasta with dbsnps from the data warhouse.",
		 is_optional  => 1,
	     },
	     organism => {
		 type  =>  'String',
		 doc   =>  "provide the organism either mouse or human; default is human",
		 is_optional  => 1,
		 default => 'human',
	     },
	     display_blast => {
		 is => 'Boolean',
		 doc   =>  "use this option if you'd like to see the alignment hsps; they will be printed in this format primer_pair_coverage,primer_pair_percent_identity,chromosome(coordinates)",
		 is_optional  => 1,
	     },
	     blast_db => {
		 type  =>  'String',
		 doc   =>  "provide a blastable database to check your primer match against; A transcriptome for rt-pcr)",
		 is_optional  => 1,
	     },
	     note => {
		 type  =>  'String',
		 doc   =>  "add a note to your ordered output file",
		 is_optional  => 1,
	     },
	     header => {
		 type  =>  'String',
		 doc   =>  "provide a header for your note string if no note enter 1",
		 is_optional  => 1,
	     },

	],
 
    
};


sub help_brief {
    return <<EOS

gmt oligo pcr-primers -h

EOS
}

sub help_synopsis {
    return <<EOS

gmt oligo pcr-primers -fasta-file

EOS
}

sub help_detail {
    return <<EOS

gmt oligo pcr-primers -fasta-file plus any desired parameter

default parameter settings are based on the preferred settings in primer_design.
by using the primer3_defaults no stipultation will be made for any primer3 parameters.
individual primer3 parameters can be set by selecting the option and a value for it
 
hspsepSmax is a blast parameter that allows the oligos to spread across the genomic sequence up to the said value. Increase this value if your expected genomic size is greater than 1000bp. 

The ordered_primer_pairs.txt shows the derived name, product size, left primer seq, left prime coordinates, right primer seq, right primer coordinates, number of perfect matches, number of near perfect matches, number of less than perfect matches, and the primer3 primer quality score.

A lower primer3 primer quality score means a better primer pair according to primer3 documentation and using primer3-defaults option generally results in a lowere primer pair quality score. 
Blast parameters and criteria for perfect matches are based on primer_design. 1 0 0 being ideal.

EOS
}


sub execute {

    my $self = shift;
    
    my $bp_id = $self->bp_id;
    my $output_name = $self->output_name;

    my $output_dir = $self->output_dir;
    unless ($output_dir && -d $output_dir) {print qq(couldn't find the output directory\n); return 0;}

    my $primers;


    my $primer_seq;
    my $filter_primers = $self->filter_primers;
    if ($filter_primers) {
	my @pa = split(/\,/,$filter_primers);
	for my $primer (@pa) {
	    $primer_seq->{$primer}=1;
	}
    }

    my $fasta_file = $self->fasta_file;

    unless (-e $fasta_file) { print qq(Can't find the fasta file\n); return 0; }
    my ($fasta) = &parse_fasta($fasta_file,$self);

    my $start = $fasta->{start};
    my $stop = $fasta->{stop};
    my $chr = $fasta->{chr};
    my $seq = $fasta->{seq};

    #my $target_depth = $self->target_depth;
    #my $length = length($seq);

    #unless ($target_depth) {$target_depth = sprintf("%d",($length/2));}
    #unless ($bp_id) { my $pos = $target_depth + $start; $bp_id = "$chr:$pos-$pos";}

    my ($span_primer_results,$primer_quality,$targets,$primer_name) = &get_span_primers($chr,$start,$stop,$seq,$self,$fasta);
    if ($span_primer_results) {
	print qq(for $primer_name See the picked primmers in $span_primer_results\n);
    } else {
	print qq(no primers were identified\n);
	return 0;
    }
    
    open(PPO,">$output_dir/$primer_name.ordered_primer_pairs.txt");

    my $note = $self->note;
    my $header = $self->header;


    if ($header) {
	if ($note) {
	    print PPO qq($header\tprimer_name\tproduct_size\ttm_left\tleft_seq\tleft_primer_coords\ttm_right\tright_seq\tright_primer_coords\tcov100id100\tcov90id100\tcov75id90\tprimer_pair_quality);
	} else {
	    print PPO qq(primer_name\tproduct_size\ttm_left\tleft_seq\tleft_primer_coords\ttm_right\tright_seq\tright_primer_coords\toriginalmatch\tnearperfectmatch\tclohom\tprimer_pair_quality);
	}
	if ($self->display_blast) {
	    print PPO qq(\talignment\n);
	} else {
	    print PPO qq(\n);
	}
    }
    if ($note) {$note = "$note\t$primer_name";} else {$note = $primer_name;}

    foreach my $primer_pair_quality (sort {$a<=>$b} keys %{$primer_quality}) {
	foreach my $paired_primers (sort keys %{$primer_quality->{$primer_pair_quality}}) {
	    my $originalmatch = $targets->{$paired_primers}->{originalmatch}; unless ($originalmatch) {$originalmatch=0;}
	    my $nearperfectmatch = $targets->{$paired_primers}->{nearperfectmatch}; unless ($nearperfectmatch) {$nearperfectmatch=0;}
	    my $clohom = $targets->{$paired_primers}->{clohom}; unless ($clohom) {$clohom=0;}
	    my $other = $targets->{$paired_primers}->{other}; unless ($other) {$other=0;}
	    my $hsp_count = $targets->{$paired_primers}->{HITCOUNT};
	    my $tm_r = $targets->{$paired_primers}->{RIGHT_TM};
	    my $tm_l = $targets->{$paired_primers}->{LEFT_TM};
	    my $hsps = $targets->{$paired_primers}->{hsps};
	    my ($left_seq,$right_seq) = split(/\:/,$paired_primers);

	    my $alignment = $targets->{$paired_primers}->{hsps};
	    unless ($primer_seq->{$left_seq} || $primer_seq->{$right_seq}) {
		my ($ls,$le,$rs,$re) = &get_primer_coords ($start,$stop,$seq,$left_seq,$right_seq);
		my $lpr = "$ls-$le";
		my $rpr = "$rs-$re";
		
		my $product_size = ($re - $ls) + 1;
		
		print PPO qq($note\t$product_size\t$tm_l\t$left_seq\t$lpr\t$tm_r\t$right_seq\t$rpr\t$originalmatch\t$nearperfectmatch\t$clohom\t$primer_pair_quality);
		if ($alignment) {
		    print PPO qq(\t$alignment\n);
		} else {
		    print PPO qq(\n);
		}
	    }
	}
    }
    print qq(see the scored primer pairs in $output_dir/$primer_name.ordered_primer_pairs.txt\n);
}


sub get_span_primers {
    my ($primer_quality,$targets);
    my ($chr,$start,$stop,$seq,$self,$fasta) = @_;
    my $output_name = $self->output_name;
    my $target_depth = $self->target_depth;
    my $length = length($seq);
    
    unless ($target_depth) {$target_depth = sprintf("%d",($length/2));}
    
    my $bp_id = $self->bp_id;
    unless ($bp_id) { my $pos = $target_depth + $start; $bp_id = "chr$chr:$pos";}
    my $primer_name = "$bp_id.$target_depth";
    if ($output_name) {$primer_name = $output_name;}
    
    print qq(\nprimers will be picked from a sequence that is $length bp in length\n\n);
    my $pick;
    ($pick,$primer_quality,$targets) = &pick_primer($primer_name,$self,$primer_quality,$targets,$fasta);
    unless ($pick) {$pick = 0;}
    
    return ($pick,$primer_quality,$targets,$primer_name);
}

sub pick_primer {

    my ($primer_name,$self,$primer_quality,$targets,$fasta) = @_;
    
    my $start = $fasta->{start};
    my $stop = $fasta->{stop};
    my $chr = $fasta->{chr};
    my $seq = $fasta->{seq};
    my $length = length($seq);

    my $target_depth = $self->target_depth;
    my $primer_perimeter = $self->primer_perimeter;
    my $bp_id = $self->bp_id;

    my ($boundary,$boundary_size);
    if ($bp_id) {
	my ($chromosome,$breakpoint1,$breakpoint2);
	if ($bp_id =~ /chr([\S]+)\:(\d+)\-(\d+)/) { 
	    $chromosome = $1;
	    $breakpoint1 = $2;
	    $breakpoint2 = $3;

	    $boundary = ($breakpoint1 - $start) - $primer_perimeter;
	    $boundary_size = ((($breakpoint2 - $breakpoint1) + 1 + $primer_perimeter + $primer_perimeter));
	}
    } elsif ($target_depth) {
	$boundary = ($target_depth - $start) - $primer_perimeter;
	$boundary_size = (1 + $primer_perimeter + $primer_perimeter);
    } else {
	$boundary_size = 1 + $primer_perimeter + $primer_perimeter;
	$boundary = sprintf("%d",(($length/2) - $primer_perimeter));
    }
    unless ($boundary && $boundary_size) {print qq(Couldn't define the primer boundary\n);}
    
    my $includestart; ##not using this parameter
    my $includesize; ##not using this parameter
    my $excludestart; ##not using this parameter
    my $excludesize; ##not using this parameter

    my $product_range = $self->product_range;
    my $product_opt_size = $self->product_opt_size;
    my $tm_min = $self->tm_min;
    my $tm_max = $self->tm_max;
    my $tm_opt = $self->tm_opt;
    my $tm_max_diff = $self->tm_max_diff; 
    my $product_tm_max = $self->product_tm_max;
    my $poly_nuc_max = $self->poly_nuc_max;
    my $psize_max = $self->psize_max;
    my $psize_min = $self->psize_min;
    my $psize_opt = $self->psize_opt;
    my $gc_max = $self->gc_max;
    my $gc_min = $self->gc_min;
    my $gc_opt = $self->gc_opt;
    my $gc_clamp = $self->gc_clamp;
    my $return_pairs = $self->return_pairs;
    my $p_pair_compl_any = $self->p_pair_compl_any;
    my $primer3_defaults = $self->primer3_defaults;

    open(OUT, ">$primer_name.primer3.parameters");
    print OUT qq(PRIMER SEQUENCE ID=$primer_name\n);
    print OUT qq(SEQUENCE=$seq\n);
    print OUT qq(TARGET=$boundary, $boundary_size\n); 

    if ($primer3_defaults) {
	if ($return_pairs) {
	    print OUT qq(PRIMER_NUM_RETURN=$return_pairs\n);
	}
	if ($product_range) {
	    print OUT qq(PRIMER_PRODUCT_SIZE_RANGE=$product_range\n);
	}
	if ($product_opt_size) {
	    print OUT qq(PRIMER_PRODUCT_OPT_SIZE=$product_opt_size\n);
	}
	if ($tm_max) {
	    print OUT qq(PRIMER_MAX_TM=$tm_max\n);
	}
	if ($tm_min) {
	    print OUT qq(PRIMER_MIN_TM=$tm_min\n);
	}
	if ($tm_opt) {
	    print OUT qq(PRIMER_OPT_TM=$tm_opt\n);
	}
	if ($tm_max_diff) {
	    print OUT qq(PRIMER_MAX_DIFF_TM=$tm_max_diff\n);
	}
	if ($product_tm_max) {
	    print OUT qq(PRIMER_PRODUCT_MAX_TM=$product_tm_max\n);
	}
	if ($poly_nuc_max) {
	    print OUT qq(PRIMER_MAX_POLY_X=$poly_nuc_max\n);
	}
	if ($psize_max) {
	    print OUT qq(PRIMER_MAX_SIZE=$psize_max\n);
	}
	if ($psize_min) {
	    print OUT qq(PRIMER_MIN_SIZE=$psize_min\n);
	}
	if ($psize_opt) {
	    print OUT qq(PRIMER_OPT_SIZE=$psize_opt\n);
	}
	if ($gc_max) {
	    print OUT qq(PRIMER_MAX_GC=$gc_max\n);
	}
	if ($gc_min) {
	    print OUT qq(PRIMER_MIN_GC=$gc_min\n);
	}
	if ($gc_opt) {
	    print OUT qq(PRIMER_OPT_GC=$gc_opt\n);
	}
	if ($gc_clamp) {
	    print OUT qq(PRIMER_GC_CLAMP=$gc_clamp\n);
	}
	if ($p_pair_compl_any) {
	    print OUT qq(PRIMER_PAIR_COMPL_ANY=$p_pair_compl_any\n);
	}
    } else {

	unless ($return_pairs) {$return_pairs=10;}
	unless ($product_range) {$product_range="125-800";}
	unless ($product_opt_size) {$product_opt_size=400;}
	unless ($tm_min) {$tm_min=56;}
	unless ($tm_max) {$tm_max=70;}
	unless ($tm_opt) {$tm_opt=63;}
	unless ($tm_max_diff) {$tm_max_diff=2;}
	unless ($product_tm_max) {$product_tm_max=85;}
	unless ($poly_nuc_max) {$poly_nuc_max=3;}
	unless ($psize_max) {$psize_max=24;}
	unless ($psize_min) {$psize_min=18;}
	unless ($psize_opt) {$psize_opt=22;}
	unless ($gc_max) {$gc_max=70;}
	unless ($gc_min) {$gc_min=30;}
	unless ($gc_opt) {$gc_opt=50;}
	unless ($p_pair_compl_any) {$p_pair_compl_any=4;}

	print OUT qq(PRIMER_NUM_RETURN=$return_pairs\n);
	print OUT qq(PRIMER_PRODUCT_SIZE_RANGE=$product_range\n);
	print OUT qq(PRIMER_PRODUCT_OPT_SIZE=$product_opt_size\n);
	print OUT qq(PRIMER_MAX_TM=$tm_max\nPRIMER_MIN_TM=$tm_min\nPRIMER_OPT_TM=$tm_opt\n);
	print OUT qq(PRIMER_MAX_DIFF_TM=$tm_max_diff\n);
	print OUT qq(PRIMER_PRODUCT_MAX_TM=$product_tm_max\n);
	print OUT qq(PRIMER_MAX_POLY_X=$poly_nuc_max\n);
	print OUT qq(PRIMER_MAX_SIZE=$psize_max\nPRIMER_MIN_SIZE=$psize_min\nPRIMER_OPT_SIZE=$psize_opt\n);
	print OUT qq(PRIMER_MAX_GC=$gc_max\nPRIMER_MIN_GC=$gc_min\nPRIMER_OPT_GC=$gc_opt\n);
	if ($gc_clamp) {
	    print OUT qq(PRIMER_GC_CLAMP=$gc_clamp\n);
	}
	print OUT qq(PRIMER_PAIR_COMPL_ANY=4\n);
    }
    print OUT qq(PRIMER_EXPLAIN_FLAG=1\n);
    print OUT qq(=\n);
    close(OUT);
#Max Complementarity
#Max 3\' Complementarity

    my $file = "$primer_name.primer3.result";
    system ("cat $primer_name.primer3.parameters | primer3 > $file"); 
    my $result;
    ($result,$primer_quality,$targets) = &blastprimer3result($primer_name,$file,$self,$primer_quality,$targets);

    system qq(rm $primer_name.primer3.parameters $file);

    if ($result) {
	return ($result,$primer_quality,$targets);

    } else {

    }
}

sub blastprimer3result {

    my ($primer_name,$pd_result,$self,$primer_quality,$targets) = @_;

    my $output_dir = $self->output_dir;

    my $hspsepSmax = $self->hspsepSmax;
    my $organism = $self->organism;
    
    open(RESULT,"$pd_result");
    my $out = "$output_dir/$primer_name.primer3.result.txt";
    open(OUT,">$out");

    my $primers_were_pricked;
    my $right_primer;
    my $left_primer;
    my $pair_count;
    my $pp_q;
    my $paired_primers;
    while (<RESULT>) {
	chomp;
	my $line = $_;

	if ($line =~ /PRIMER_LEFT[\S]+TM\=(\S+)/) {
	    $targets->{$paired_primers}->{LEFT_TM} = $1;
	}
	if ($line =~ /PRIMER_RIGHT[\S]+TM\=(\S+)/) {
	    $targets->{$paired_primers}->{RIGHT_TM} = $1;
	}

	if ($line =~ /PRIMER_PAIR_QUALIT[\S]+=(\S+)/) {
	    $pp_q = $1;
	    undef($paired_primers);
	}
	if ($line =~ /(PRIMER\_\S+\_SEQUENCE)\=(\S+)/) {
	    my $pid = $1;
	    my $p_seq = $2;
	    
	    print OUT qq($line\n);

	    if ($pid =~ /LEFT/) {$left_primer=$p_seq;}
	    if ($pid =~ /RIGHT/) {
		$right_primer=$p_seq;
		
		my $rev_right_primer = &reverse_complement_allele($right_primer);

		my $blast_fasta = "$output_dir/$primer_name.$left_primer\_$right_primer.fasta";
		open(PF,">$blast_fasta");
		print PF qq(>$left_primer$rev_right_primer.fasta\n$left_primer$rev_right_primer\n);
		close (PF);

		my $blast_result = "$output_dir/$primer_name.$left_primer\_$right_primer.blastresult.txt";

		my $s = length($p_seq);
		my $n = $s + $s;

		#system qq(blastn /gscmnt/200/medseq/analysis/software/resources/B36/HS36.fa $pid.fasta -nogap -M=1 -N=-$n -S2=$s -S=$s | blast2gll -s > $pid.out);

		my $blast_db = $self->blast_db;
		if ($blast_db) {
		    system qq(blastn $blast_db $blast_fasta M=1 N=-3 Q=3 R=3 hspsepSmax=$hspsepSmax topcomboN=3 B=3 V=3 | blast2gll -s > $blast_result);
		} elsif ($organism eq "mouse") {
		    system qq(blastn /gscmnt/200/medseq/analysis/software/resources/MouseB37/MS37.fa $blast_fasta M=1 N=-3 Q=3 R=3 hspsepSmax=$hspsepSmax topcomboN=3 B=3 V=3 | blast2gll -s > $blast_result);
		} else {
		    system qq(blastn /gscmnt/200/medseq/analysis/software/resources/B36/HS36.fa $blast_fasta M=1 N=-3 Q=3 R=3 hspsepSmax=$hspsepSmax topcomboN=3 B=3 V=3 | blast2gll -s > $blast_result);
		}
		
		#my $file = "$output_dir/$primer_name.$pid.out";
		#my $paired_primers = "$left_primer:$right_primer";
		$paired_primers = "$left_primer:$right_primer";

		$targets->{$paired_primers}->{LEFT} = $left_primer;
		$targets->{$paired_primers}->{RIGHT} = $right_primer;
		$primer_quality->{$pp_q}->{$paired_primers}=1;

		my ($hit_count,$loc,$targets) = &count_blast_hits($blast_result,$paired_primers,$targets);
		if ($self->display_blast) {$targets->{$paired_primers}->{hsps}=$loc;}

		system qq(rm $blast_result);
		system qq(rm $blast_fasta);

		if ($pair_count) {
		    print OUT qq(PRIMER_PAIR_BLAST_HIT_COUNT_$pair_count=$hit_count\t$loc\n);
		} else {
		    print OUT qq(PRIMER_PAIR_BLAST_HIT_COUNT=$hit_count\t$loc\n);
		}$pair_count++;

		undef($right_primer);
		undef($left_primer);

		$primers_were_pricked = 1;

	    }

	} else {

	    print OUT qq($line\n);

	}
    }
    if ($primers_were_pricked) {
	return($out,$primer_quality,$targets);
    } else {
	return(0);
    }

}

sub count_blast_hits {
    my $HSPS;
    my ($blastout,$paired_primers,$targets) = @_;
    open(IN,$blastout);
    my $blast_hit_counts=0;
    my $location;
    while (<IN>) {
	chomp;
	my $line = $_;
	my (@sub_line) = split(/\;/,$line);
	my ($subject_id,$query_id,$subject_cov,$query_cov,$percent_identity,$bit_score,$p_value,$subject_length,$query_length,$alignment_bases,$HSPs) = split(/\s+/,$sub_line[0]);
	my $out = qq($line);

	my $hsp_count = @sub_line;
	my $count = $targets->{$paired_primers}->{HITCOUNT};
	unless($count) {$count = 0;}
	my $new_count = $hsp_count + $count;
	$targets->{$paired_primers}->{HITCOUNT}=$new_count;
	
	if ($query_cov >=100 && $percent_identity >= 100) {
	    $targets->{$paired_primers}->{originalmatch}++;
	} elsif ($query_cov > 90 && $percent_identity >= 100) {
	    $targets->{$paired_primers}->{nearperfectmatch}++;
	} elsif ($query_cov > 75 && $percent_identity >= 90) {
###  good place for $confidence 
	    $targets->{$paired_primers}->{clohom}++;
	} else {
	    $targets->{$paired_primers}->{other}++;
	}

	if ($location) {
	    my $loc1 = $location;
	    my ($loc) = $HSPs =~ /(\S+)\:/;
	    $location = "$loc1\:\:$subject_id($loc)";
	    my $hsp1 = $HSPS;
	    $HSPS = "$hsp1\:\:$query_cov,$percent_identity,$subject_id($HSPs)";
	} else {
	    my ($loc) = $HSPs =~ /(\S+)\:/;
	    $location = "$subject_id($loc)";
	    $HSPS = "$query_cov,$percent_identity,$subject_id($HSPs)";
	}
	
	for my $n (@sub_line) {

	    my $base_hsp = $HSPS;

	    my ($hit) = $n =~ /\((\S+)\)/;
	    $n =~ s/\s//gi;
	    if ($n =~ /^\d/) {
		unless ($location =~ /$n/) {
		    $HSPS = "$base_hsp\;$n";
		    my $n1 = $location;
		    my ($loc) = $n =~ /(\S+)\:/;
		    $location = "$n1\:\:$subject_id($loc)";
		}
	    }
	    
	    while ($hsp_count > 1) {
                $hsp_count--;
		$blast_hit_counts++;
	    }
	}
    }
    close (IN);
    #system qq(rm $blastout);
    return ($blast_hit_counts,$HSPS,$targets);
}


sub get_primer_coords {
    my ($start,$stop,$seq,$left_primer,$right_primer) = @_;

    my $mseq = "X" . $seq . "X";
    my ($s1,$e1) = split($left_primer,$mseq);
    my @s_s1 = split(//,$s1);
    my $n1 = @s_s1;

    my $ls = $start + $n1 - 1;
    my $le = length($left_primer) + $ls - 1;

    my $rev_right_primer = &reverse_complement_allele ($right_primer);
    my ($s2,$e2) = split($rev_right_primer,$mseq);
    my @s_s2 = split(//,$s2);
    my $n2 = @s_s2;

    my $rs = $start + $n2 - 1;
    my $re = length($rev_right_primer) + $rs - 1;

    return ($ls,$le,$rs,$re);

}

sub reverse_complement_allele {
    my ($allele_in) = @_;

    unless ($allele_in =~ /[ACGT]/) { return ($allele_in); }
    
    my $seq_1 = new Bio::Seq(-seq => $allele_in);
    my $revseq_1 = $seq_1->revcom();
    my $rev1 = $revseq_1->seq;
    
    my $r_base = $rev1;
    
    return $r_base;
}

sub parse_fasta {
    my $fasta;
    my ($fasta_file,$self) = @_;
    my @sequence;
    open(FA,$fasta_file) || die "couldn't open the fasta file.\n" ;

    my ($chr,$start,$stop,$ori);
    while (<FA>) {
	chomp;
	my $line = $_;
	if ($line =~ /^\>/) {
	    ($chr) = /Chr\:([\S]+)/;if ($chr){$chr =~ s/\,//;}
	    ($start,$stop) = /Coords[\s]+(\d+)\S(\d+)/;
	    ($ori) = /Ori \((\S)\)/;
	    unless ($ori) {$ori = "+";}
	    unless ($chr && $start && $stop) {
		warn "\n\nThe fasta header format should be checked. Could not parse out the chromosome and coordinate information.\n\n";
		my ($fasta_name) = $line =~ /^\>([\S]+)/;
		$fasta_name =~ s/.fasta//;
		
		$start = 0;$stop=0;$chr=$fasta_name;
	    }
	    
	    $fasta->{start}=$start;
	    $fasta->{stop}=$stop;
	    $fasta->{chr}=$chr;
	    
	} else {
	    $line =~ s/\s//gi;
	    my @bases = split(//,$line);
	    for my $base (@bases) {
		push(@sequence,$base);
	    }
	}
    }
    close(FA);
    my $seq = join "" , @sequence;
    
    my $mask_primers = $self->mask_primers;
    if ($mask_primers) {
	my @pa = split(/\,/,$mask_primers);
	for my $primer (@pa) {
	    my $n_seq = 'N' x length($primer);
	    $seq =~ s/$primer/$n_seq/gi;
	}
    }
    
    my $mask_list = $self->mask_list;
    my $mask_dbsnps = $self->mask_dbsnps;

    if ($mask_list) {
	if ($chr && $start && $stop) {
	    my ($screen) = &get_screen($chr,$start,$stop,$mask_list);
	    if ($mask_dbsnps) {
		($screen) = &get_dbsnps($chr,$start,$stop,$screen,$mask_dbsnps,$self);
	    }
	    my @sequence = split(//,$seq);
	    my @masked_seq;
	    for my $base (@sequence) {
		if ($ori eq "-") {$start = $stop;}
		my $screened = $screen->{$start};
		if ($ori eq "-") {
		    $start--;
		} else {
		    $start++;
		}
		if ($screened) {
		    $base = "N";
		}
		push(@masked_seq,$base);
	    }
	    $seq = join '' , @masked_seq;
	} else {
	    print qq(Sequence was not masked. Can not mask the sequence unless the fasta header info is provided\n);
	}
    }
    unless ($seq) { die "didn't find a sequence in the fasta file\n"; }
    $fasta->{seq}=$seq;
    return ($fasta);
}

sub get_screen {
    my $screen;
    my ($chr,$start,$stop,$mask_list) = @_;
    open(SCREEN,$mask_list) || die ("couldn't open the screen file\n\n");
    while (<SCREEN>) {
	chomp;
	my $line = $_;
	my ($chrom,$pos) = (split(/[\s]+/,$line))[0,1];
	if ($chr eq $chrom) {
	    if ($pos >= $start && $pos <= $stop) {
		$screen->{$pos}=1;
	    }
	}
    } close (SCREEN);
    return($screen);
}

sub get_dbsnps {

    my ($chr,$start,$stop,$screen,$mask_dbsnps,$self) = @_;

    my $organism = $self->organism;
    my $g;
    if ($organism eq "mouse") {
	print qq(you may want to check if the dbsnps for mouse have been loaded in the data warhouse before relying on this method to screen your sequence. If they haven't you can compose a list of sites you'd like to mask and use the mask-list option\n);
	$g = GSC::Sequence::Genome->get(sequence_item_name => 'NCBI-mouse-buildC57BL6J');
    } else {
	$g = GSC::Sequence::Genome->get(sequence_item_name => 'NCBI-human-build36');
    }
    my $c = $g->get_chromosome($chr);
    for my $pos ($start..$stop) {
	my @t = $c->get_tags( begin_position => {  operator => 'between', value => [$pos,$pos] },);
	for my $t (@t) {
	    if ($t->sequence_item_type eq 'variation sequence tag') {
		my $variation_type = $t->variation_type;
		my $ref_id = $t->ref_id;
		my $allele_description = $t->allele_description;
		my $validated = $t->is_validated;
		my $seq_length = $t->seq_length;
		my $stag_id = $t->stag_id;
		my $unzipped_base_string = $t->unzipped_base_string;
		my $end = $pos + ($seq_length - 1);

		print qq($ref_id $variation_type $seq_length $pos $end $validated \n);
		for my $p ($pos..$end) {
		    $screen->{$pos}=1;
		}
	    }
	}
    }
    return ($screen);
}

1;
