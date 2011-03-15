package Genome::Model::Tools::DesignTranscriptSequence;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::DesignTranscriptSequence {
    is => 'Command',                    
    has => [ # specify the command's properties (parameters) <--- 
	     

	     chromosome => {
		 type  =>  'String',
		 doc   =>  "chromosome ie {1,2,...,22,X,Y}",
	     },
	     start => {
		 type  =>  'Number',
		 doc   =>  "build 36 start coordinate of the variation",
	     },
	     stop => {
		 type  =>  'Number',
		 doc   =>  "build 36 stop coordinate of the variation; default will be equal to the start coordinate",
		 is_optional  => 1,
	     },
	     variation_type => {  #predicted_type
		 type  =>   'String',
		 doc   =>   "one of the following {coding_snp,coding_ins,coding_del,splice_site_snp}",
	     },
	     transcript => {
		 type  =>   'String',
		 doc   =>   "The transcript the variation was annotated with",
	     },
	     reference_allele => {
		 type  =>   'String',
		 doc   =>   "the reference base/s (ie if your variation_type is a snp This will be ACG or T if your variation_type is an ins this will be a -, and if your variation_type is a del this will be the bases from the start to the end of you del) this is optional if not provided it will be derived if it is provided, it will be used as a check",
		 is_optional  => 1,
	     },
	     variant_allele => {
		 type  =>   'String',
		 doc   =>   "This should be the build 36 bases in the positive orientation that represent the variation",
	     },
	     number_of_flank_bases => {
		 type  =>  'Number',
		 doc   =>  "provide the number of bases you would like on either side of your variation; default will be equal to 200",
		 is_optional  => 1,
	     },
	     include_utr => {
		 type  =>  'Boolean',
		 doc   =>  "use this option if you would like UTR regions included in the transcript sequence",
		 is_optional  => 1,
	     },

	     ],
	
    
};

sub help_brief {
    return <<EOS
  This tool was design to retrieve transcript sequence centered around some variation. Intended to be used as tool to derive a sequence to be used in RT-PCR primer design.
EOS
}

sub help_synopsis {
    return <<EOS

running...

gmt design-transcript-sequence 
 
...will provide you with masked "snp's and repeat's" and unmasked sequence for the said amount of bases on either side of your variation. Your information will be returned as stdout on your screen in this format

chromosome,start,stop,variation_type,transcript_id,reference_allele,variant_allele,number_of_flank_bases,left_flank_seq_masked [reference_allele/variant_allele] right_flank_seq_masked,left_flank_seq [reference_allele/variant_allele] right_flank_seq

EOS
}

sub help_detail {
    return <<EOS 


running for a missense snp

gmt design-transcript-sequence --chromosome 1 --start 241429086 --transcript NM_014812 --variation-type coding_snp --number-of-flank-bases 20 --variant-allele G --reference-allele T

  will result in

    1,241429086,241429086,coding_snp,NM_014812,T,G,20,CCCACCATGACGGCTGCCCA [T/G] NTAATGGAGTACCACGGGGC,CCCACCATGACGGCTGCCCA [T/G] ATAATGGAGTACCACGGGGC


running for a in_frame_ins

gmt design-transcript-sequence --chromosome 1 --start 241429086 --transcript NM_014812 --variant-allele ATA --variation-type coding_ins --number-of-flank-bases 20 --stop 241429087

  will result in

    1,241429086,241429087,coding_ins,NM_014812,-,ATA,20,CCACCATGACGGCTGCCCAN [-/ATA] NTAATGGAGTACCACGGGGC,CCACCATGACGGCTGCCCAT [-/ATA] ATAATGGAGTACCACGGGGC


running for a frame_shift_del

gmt design-transcript-sequence --chromosome 1 --start 241429086 --transcript NM_014812 --variant-allele - --variation-type coding_del --number-of-flank-bases 20 --stop 241429087

  will result in

    1,241429086,241429087,coding_del,NM_014812,TA,-,20,CCCACCATGACGGCTGCCCA [TA/-] TAATGGAGTACCACGGGGCA,CCCACCATGACGGCTGCCCA [TA/-] TAATGGAGTACCACGGGGCA


running for a splice_site_snp

gmt design-transcript-sequence --chromosome 19 --start 17247609 --transcript NM_001033549 --variation-type splice_site_snp --number-of-flank-bases 20 --variant-allele T --reference-allele G

  will result in

    19,17247609,17247609,splice_site_snp,NM_001033549,G,T,20,GGCCTCCTGTTCCACCTTCA [ATCTGGAAGGACTTTTCAGCCTCAT/-] CCAGCAGAAAACTGAGCTTC,GGCCTCCTGTTCCACCTTCA [ATCTGGAAGGACTTTTCAGCCTCAT/-] CCAGCAGAAAACTGAGCTTC


EOS
}


sub execute {

    my $self = shift;
    
    my $chromosome = $self->chromosome;
    #unless ($chromosome =~ /[1..22]/ || $chromosome =~ /^[XY]$/) {$self->error_message("please provide the chromosome"); return 0;}
    my $start = $self->start;
    unless ($start =~ /^[\d]+$/) {$self->error_message("please provide the Build 36 start coordinate"); return 0; }
    my $stop = $self->stop;
    my $variation_type = $self->variation_type; #{coding_snp,coding_ins,coding_del,splice_site_snp,splice_site_ins,splice_site_del}
    
    unless ($stop) {if ($variation_type =~ /ins/) {$stop=$start+1;} else {$stop=$start;}} #will assume start and stop to be the same
    
    #unless ($variation_type eq "coding_snp" || $variation_type eq "coding_ins" || $variation_type eq "coding_del" || $variation_type eq "splice_site_snp" || $variation_type eq "splice_site_ins" || $variation_type eq "splice_site_del") { die "please provide the variation_type\n"; }

    unless ($variation_type eq "coding_snp" || $variation_type eq "coding_ins" || $variation_type eq "coding_del" || $variation_type eq "splice_site_snp") { $self->error_message("please provide the variation_type"); return 0; }
    
    my $transcript = $self->transcript;
    unless ($transcript) {$self->error_message("please provide the transcript id"); return 0;}
    my $reference_allele = $self->reference_allele;
    unless ($reference_allele) { if ($variation_type =~ /ins/) {$reference_allele = "-";} else {$reference_allele = &get_ref_base($chromosome,$start,$stop); }}
    my $variant_allele = $self->variant_allele;
    if ($variation_type =~ /del/) {$variant_allele = "-";}
    
    if ($variation_type =~ /snp/ && $start != $stop) {$self->error_message("the start and stop coordinates for a snp should be equal"); return 0; }
						       
    unless ($variant_allele) {$self->error_message("please provide the variant allele"); return 0;}
    my $number_of_flank_bases = $self->number_of_flank_bases;
    unless ($number_of_flank_bases) {$number_of_flank_bases=200;}
    
    my $line = "$chromosome,$start,$stop,$variation_type,$transcript,$reference_allele,$variant_allele,$number_of_flank_bases";
    
###########################
    
    #return 0;
    #open(OUT,">transcript_coords.txt");
    
    my $build = Genome::Model::ImportedAnnotation->get(name => 'NCBI-human.combined-annotation')->build_by_version(0);
    my $genome = GSC::Sequence::Genome->get(sequence_item_name => 'NCBI-human-build36');
    my $chr = $genome->get_chromosome($chromosome);
    
    my $build_id =$build->build_id;
    
    my $t = Genome::Transcript->get( transcript_name => $transcript, build_id => $build_id );
    my $tseq = $t->cds_full_nucleotide_sequence;
    #my $gene_name = $t->gene_name;
    
    my @substructures = $t->ordered_sub_structures;
    
    my $total_substructures = @substructures;
    my $t_n = 0;
    
    my $transcript_targetbase_start;
    my $transcript_targetbase_stop;
    my $trans_base_count=0;
    my @transcipt_seq;
    my @ucscrefseq;
    #print OUT qq($chromosome,$start,$stop,$transcript\n);
    
    my $strand = $t->strand;
    #print qq($strand\n);
    my $frame;
    my $aa_n;

    my $counted_regions;
    if (@substructures) {
	
	my @mask_snps_and_repeats_sequence;
	my ($ttss,$ssttss);

	while ($t_n < $total_substructures) {
	    
	    #for my $t_regoin (@substructures) {
	    my $t_regoin = $substructures[$t_n];
	    $t_n++;
	    
	    #if (($t_regoin->{structure_type} eq "cds_exon") || ($t_regoin->{structure_type} eq "utr_exon")) {

	    if ((($self->include_utr) && (($t_regoin->{structure_type} eq "cds_exon") || ($t_regoin->{structure_type} eq "utr_exon"))) || ($t_regoin->{structure_type} eq "cds_exon")) {

		#print OUT qq(\n);


		my $tr_start = $t_regoin->{structure_start};
		my $tr_stop = $t_regoin->{structure_stop};

		unless ($counted_regions->{$chromosome}->{$tr_start}->{$tr_stop}) { #This was put in place because the coordinates for some utr in ENST00000376087 were duplicated with different sequence represented 
		    $counted_regions->{$chromosome}->{$tr_start}->{$tr_stop}=1;
		    
		    
		    my $refseq = &get_ref_base($chromosome,$tr_start,$tr_stop);

		    #print qq($t_regoin->{structure_type} $tr_start $tr_stop\n);
		    
		    
		    for my $n ($tr_start..$tr_stop) {
			$trans_base_count++;
			$frame++;
			#print OUT qq($n-$frame-$trans_base_count );
			if ($frame == 3) {
			    $aa_n++;
			    #print OUT qq($aa_n\n);
			    $frame=0;
			}
			
			if ($n == $start) {
			    $transcript_targetbase_start=$trans_base_count;
			}
			if ($n == $stop) {
			    $transcript_targetbase_stop=$trans_base_count;
			}
			
			
			#if ($variation_type =~ /splice_site/) {
			my $ss1 = $tr_start - 1;
			my $ss2 = $tr_start - 2;
			
			my $ss3 = $tr_stop + 1;
			my $ss4 = $tr_stop + 2;
			

			if ($start == $ss1 || $start == $ss2 || $start == $ss3 || $start == $ss4) {
			    $ttss=1;$ssttss=1;
			    if ($n == $tr_start) {
				$transcript_targetbase_start=$trans_base_count;
			    } 
			    if ($n == $tr_stop) {
				$transcript_targetbase_stop=$trans_base_count;
			    }
			}
			elsif ($stop == $ss1 || $stop == $ss2 || $stop == $ss3 || $stop == $ss4) {
			    $ttss=1;$ssttss=1;
			    if ($n == $tr_start) {
				$transcript_targetbase_start=$trans_base_count;
			    } 
			    if ($n == $tr_stop) {
				$transcript_targetbase_stop=$trans_base_count;
			    }
			}
			else {
			    $ttss = 0;
			}
		    }
		    
		    my $tr_seq = $t_regoin->{nucleotide_seq};
		    
		    
		    
		    if ($strand eq "-1") {$tr_seq = &reverse_complement_allele($tr_seq);}
		    
		    my $exp_length = $tr_stop - ($tr_start - 1);
		    my $ref_length = length($refseq);
		    my $tr_length = length($tr_seq);
		    
		    
		    unless ($tr_seq eq $refseq) {
			print qq(there appears to be a discrepancy between the transcript sequence provide by the database and the reference sequence from NCBI Build 36\nWill make an attempt to select the correct sequence based on the expected length of the sequence\n);
			
			if ($tr_length == $exp_length) {
			    print qq(sequence from db is the correct lenght\n);
			} elsif ($ref_length == $exp_length) {
			    $tr_seq = $refseq;
			    print qq(sequence from NCBI B36 is the correct length and will be used in place of the sequence from the database for this region\n);
			} else {
			    print qq(results from this run will need to be verified as there is a discrpency indenfying the sequence that could not be resolve\n);
			}
		    }
		    
		    
		    if ($ttss) {$reference_allele = $tr_seq;$variant_allele = "-";}
		    
		    push(@transcipt_seq,$tr_seq);
		    my $masked_tr_seq = $chr->mask_snps_and_repeats(begin_position       => $tr_start, 
								    end_position         => $tr_stop,
								    sequence_base_string => $tr_seq);
		    
		    push(@mask_snps_and_repeats_sequence,$masked_tr_seq);
		    push(@ucscrefseq,$refseq);
		    
		    
		    #print qq($t_regoin->{structure_type}\t$chromosome\t$tr_start\t$tr_stop\t$exp_length\t$tr_length\t$ref_length\n$tr_seq\n$refseq\n);
		    
		    
		}
	    }
	}
	
	my $masked_transcript_seq = join '' , @mask_snps_and_repeats_sequence;
	my $transcript_seq = join '' , @transcipt_seq ;
	my $refseq = join '' , @ucscrefseq;
	
	my $left_flank_start = $transcript_targetbase_start - $number_of_flank_bases;
	my $left_flank_stop = $number_of_flank_bases;
	if ($left_flank_start < 1) {
	    $left_flank_start = 1;
	    $left_flank_stop = $transcript_targetbase_start - 1;
	}
	
	my $left_flank_seq_masked = substr($masked_transcript_seq,$left_flank_start - 1,$left_flank_stop);
	my $left_flank_seq = substr($transcript_seq,$left_flank_start - 1,$left_flank_stop);
	my $left_flank_refseq = substr($refseq,$left_flank_start - 1,$left_flank_stop);
	
	if ($variation_type =~ /ins/) {
	    $left_flank_seq_masked = substr($masked_transcript_seq,$left_flank_start,$left_flank_stop);
	    $left_flank_seq = substr($transcript_seq,$left_flank_start,$left_flank_stop);
	    $left_flank_refseq = substr($refseq,$left_flank_start,$left_flank_stop);
	}
	
	my $right_flank_start = $transcript_targetbase_stop;
	my $right_flank_stop = $number_of_flank_bases;
	my $mtsl = length($masked_transcript_seq);
	if ($mtsl - $right_flank_start < $number_of_flank_bases) {$right_flank_stop = $mtsl - $right_flank_start;}
	my $right_flank_seq_masked = substr($masked_transcript_seq,$right_flank_start,$right_flank_stop);
	my $right_flank_seq = substr($transcript_seq,$right_flank_start,$right_flank_stop);
	my $right_flank_refseq = substr($refseq,$right_flank_start,$right_flank_stop);
	
	if ($variation_type =~ /ins/) {
	    $right_flank_seq_masked = substr($masked_transcript_seq,$right_flank_start - 1,$right_flank_stop);
	    $right_flank_seq = substr($transcript_seq,$right_flank_start - 1,$right_flank_stop);
	    $right_flank_refseq = substr($refseq,$right_flank_start - 1,$right_flank_stop);
	}
	
	my $end = $stop - $start + 1;
	my $target_seq = substr($transcript_seq,$transcript_targetbase_start - 1,$end);
	my $target_refseq = substr($refseq,$transcript_targetbase_start - 1,$end);
	
	
	unless ($target_seq eq $reference_allele) {
	    unless($variation_type =~ /splice_site/ || ($variation_type =~ /ins/ && $reference_allele eq "-")) {
		print qq(warning target_seq does not equal the ref allele  \($target_seq not eq $reference_allele\)\n);
		$reference_allele = $target_refseq;
	    }
	}

	if ($variation_type =~ /ins/) {$reference_allele = "-";}
	if ($variation_type =~ /splice_site/) { unless ($ssttss) {print qq(Your coordinate was not identified in a splice site of this transcript, your result will reflect that of a coding_snp\n);}}
	#if ($ssttss) { unless ($variation_type =~ /splice_site/) { print qq(\nYour coordinate was identified in a splice site of this transcript, try rerunning with the variant type as splice_site_snp\n\n);exit(1);}}
	if ($ssttss) { unless ($variation_type =~ /splice_site/) { $self->error_message("Your coordinate was identified in a splice site of this transcript, try rerunning with the variant type as splice_site_snp"); return 0; }}

	#$self->result = "$line,$left_flank_seq_masked [$reference_allele\/$variant_allele] $right_flank_seq_masked,$left_flank_seq [$reference_allele\/$variant_allele] $right_flank_seq";

	my $result = "$line,$left_flank_seq_masked [$reference_allele\/$variant_allele] $right_flank_seq_masked,$left_flank_seq [$reference_allele\/$variant_allele] $right_flank_seq";
	print qq($result\n);
	
	return 1;
	
    } else {
	$self->error_message("No sequence defined");
	return 0;
    }
}



sub reverse_complement_allele {
    my ($allele_in) = @_;
    my $seq_1 = new Bio::Seq(-seq => $allele_in);
    my $revseq_1 = $seq_1->revcom();
    my $rev1 = $revseq_1->seq;
    return $rev1;
}


sub get_ref_base {

    use Bio::DB::Fasta;
    my $RefDir = "/gscmnt/sata180/info/medseq/biodb/shared/Hs_build36_mask1c/";
    my $refdb = Bio::DB::Fasta->new($RefDir);

    my ($chr_name,$chr_start,$chr_stop) = @_;
    my $seq = $refdb->seq($chr_name, $chr_start => $chr_stop);
    $seq =~ s/([\S]+)/\U$1/;

    if ($seq =~ /N/) {warn "your sequence has N in it\n";}

    return $seq;
    
}

1;



