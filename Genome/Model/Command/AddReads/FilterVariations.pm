package Genome::Model::Command::AddReads::FilterVariations;

use strict;
use warnings;

use above "Genome";
use Command; 

use FileHandle;

class Genome::Model::Command::AddReads::FilterVariations {
    is => ['Genome::Model::EventWithRefSeq'],
    sub_classification_method_name => 'class',
    has => [
#        normal_id            => { is => 'Integer', 
#                                doc => 'Identifies the normal genome model.' },
                                   
                                   
    ]
};


sub sub_command_sort_position { 90 }

sub help_brief {
    "Create filtered lists of variations."
}

sub help_synopsis {
    return <<"EOS"
    genome-model postprocess-alignments filter-variations --model-id 5 --ref-seq-id 22 
EOS
}

sub help_detail {
    return <<"EOS"
Create filtered list(s) of variations.
EOS
}

sub command_subclassing_model_property {
    "filter_ruleset_name"
}

sub get_metrics_hashref_for_normal_sample {
    my ($self) = @_;

    my $chromosome = $self->ref_seq_id;
    my $model = $self->model;
    
    my $model_name = $model->name;
    my $normal_name = $model_name;
    $normal_name =~ s/98tumor/34skin/g;
    my $normal_model = Genome::Model->get('name like' => $normal_name);
    unless ($normal_model) {
        $self->error_message(sprintf("normal model matching name %s does not exist.  please verify this first.", $normal_name));
        return undef;
    }
    
    # Get metrics for the normal sample for processing.
    my $latest_normal_build = $normal_model->latest_build_event; 
    unless ($latest_normal_build) {
        $self->error_message("Failed to find a build event for the comparable normal model " . $normal_model->name); 
        return;
    } 

    my ($equivalent_skin_event) = 
        grep { $_->isa("Genome::Model::Command::AddReads::PostprocessVariations")  } 
        $latest_normal_build->child_events( 
            ref_seq_id => $self->ref_seq_id
        );

    unless ($equivalent_skin_event) {
        $self->error_message("Failed to find an event on the skin model to match the tumor.  Probably need to re-run after that completes.  In the future, we will have the tumor/skin filtering separate from the individual model processing.\n");
        return;
    } 
    my $normal_sample_variation_metrics_file_name = $equivalent_skin_event->variation_metrics_file;
    unless (-e $normal_sample_variation_metrics_file_name) {
        $self->error_message("Failed to find variation metrics for \"normal\": $normal_sample_variation_metrics_file_name");
        return;
    }

    # construct a hashref for the normal data
    #my $ov_cmd = "/gscuser/bshore/src/perl_modules/Genome/Model/Tools/Maq/ovsrc/maqval $map_file_path $detail_file_sort $alignment_quality |";
    my $ov_fh = IO::File->new($normal_sample_variation_metrics_file_name);
    unless ($ov_fh) {
        $self->error_message("Unable to open $normal_sample_variation_metrics_file_name for comparision to \"normal\": $!");
        return;
    }
    my %normal;
    while (<$ov_fh>) {
        chomp;
        unless (/^\d+\s+/) {
            next;
        }
        #RC(A,C,G,T) URC(A,C,G,T) URSC(A,C,G,T) REF Ref(RC,URC,URSC,Q,MQ) Var1(RC,URC,URSC,Q,MQ) Var2(RC,URC,URSC,Q,MQ)
        s/\t\t/\t/g;
        my ($chr, $start, $ref_sequence, $iub_sequence, $quality_score,
            $depth, $avg_hits, $high_quality, $unknown,
            $rc_arr, $urc_arr, $urc26_arr, $ursc_arr,
            $ref, $ref_count_arr, @variant_pair) =
                                split("\t");
        my ($ref_rc, $ref_urc, $ref_urc26, $ref_ursc, $ref_bq, $ref_maxbq) =
                split(',',$ref_count_arr);
        $normal{$chr}{$start}{$ref} = $ref_rc;
        do {
            my $var = shift @variant_pair;
            my $var_count_arr = shift @variant_pair;
            unless (defined($var) && defined($var_count_arr)) {
                    last;
            }
            my ($var_rc, $var_urc, $var_urc26, $var_ursc, $var_bq, $var_maxbq) =
                    split(',',$var_count_arr);
            $normal{$chr}{$start}{$var} = $var_rc;
        } while (scalar(@variant_pair));
    }
    $ov_fh->close;
    return \%normal;
}

my %IUBcode=(
	     A=>'AA',
	     C=>'CC',
	     G=>'GG',
	     T=>'TT',
	     M=>'AC',
	     K=>'GT',
	     Y=>'CT',
	     R=>'AG',
	     W=>'AT',
	     S=>'GC',
	     D=>'AGT',
	     B=>'CGT',
	     H=>'ACT',
	     V=>'ACG',
	     N=>'ACGT',
	    );

sub SNPFiltered {
	my ($self, $snp_file_filtered) = @_;
	my $chromosome = $self->ref_seq_id;
	my $model = $self->model;

	my ($snp_file) = $model->_variant_list_files($chromosome);
	my $snp_fh = IO::File->new($snp_file);
	unless ($snp_fh) {
		$self->error_message(sprintf("snp file %s does not exist.  please verify this first.",
																 $snp_file));
		return 0;
	}
	my $snp_filtered_fh = IO::File->new(">$snp_file_filtered");
	unless ($snp_filtered_fh) {
		$self->error_message(sprintf("snp file %s can not be created.",
																 $snp_file_filtered));
		return 0;
	}
	while (<$snp_fh>) {
		chomp;
		my ($id, $start, $ref_sequence, $iub_sequence, $quality_score,
				$depth, $avg_hits, $high_quality, $unknown) = split("\t");
		my $genotype = $IUBcode{$iub_sequence};
		my $cns_sequence = substr($genotype,0,1);
		my $var_sequence = (length($genotype) > 2) ? 'X' : substr($genotype,1,1);
		if ($ref_sequence eq $cns_sequence &&
				$ref_sequence eq $var_sequence) {
			next;										# no variation
		}
		if ($depth > 2) {
			print $snp_filtered_fh $_ . "\n";
		}
	}
	$snp_fh->close;
	$snp_filtered_fh->close;
	return 1;
}

sub execute {
    my $self = shift;
    $DB::single = 1; # when debugging, stop here...
    
    unless ($self->revert) {
        $self->error_message("Error ensuring previous runs have been cleaned up.");
        return;
    }

    my $chromosome = $self->ref_seq_id;
    my $model = $self->model;

    my ($snp_file) = $model->_variant_list_files($chromosome);
    my ($pileup_file) = $model->_variant_pileup_files($chromosome);
    my ($detail_file) = $model->_variant_detail_files($chromosome);

		# ensure the reference sequence exists.
    my $ref_seq_file =  $model->reference_sequence_path . "/all_sequences.bfa";
    
    unless (-e $ref_seq_file) {
			$self->error_message(sprintf("reference sequence file %s does not exist.  please verify this first.", $ref_seq_file));
			return;
    }

    my ($filtered_list_dir) = $model->_filtered_variants_dir();
    $self->status_message("Filtered variants directory is $filtered_list_dir");
    unless (-d $filtered_list_dir) {
        mkdir $filtered_list_dir;
        `chmod g+w $filtered_list_dir`;
    }

		my $snp_file_filtered = $filtered_list_dir . "snp_filtered_${chromosome}.csv";

		unless ($self->SNPFiltered($snp_file_filtered)) {
			return;
		}

    # This creates a map file in /tmp which is actually a named pipe
    # streaming the data from the original maps.
    # It can be used only once.  Run this again if you need to use it multiple times.
		

		my $alignment_quality = 1;
		my $normal_href = $self->get_metrics_hashref_for_normal_sample();
		unless (defined($normal_href)) {
			return;
		}

		my ($file, $basename, $qvalue_level, $bq);
		my $specificity = 'default';
		#my $ruleset = 'dtr2a';
		my $ruleset = 'dtr3e';



		my %specificity_maqq;
		if ($ruleset eq 'dtr2a') {
			%specificity_maqq = (
												max => [ 121, 0 ],
												95 => [ 110, 0 ],
												90 => [ 70, 0 ],
												75 => [ 30, 0 ],
												default => [ 29, 0 ],
												min => [ 29, 0 ]
											 );
		} else {
			%specificity_maqq = (
													 min => [ 5, 16 ],
													 default => [ 30, 16 ],
													 90 => [ 40, 22 ],
													 95 => [ 50, 26 ],
													 max => [ 120, 26 ],
													);
		}

		my $spec_ref = (exists($specificity_maqq{$specificity})) ?
			$specificity_maqq{$specificity} : $specificity_maqq{default};
		($qvalue_level, $bq) = @$spec_ref;
		$qvalue_level ||= 30;
		$bq ||= 16;

		$basename = $filtered_list_dir . '/filtered';

		my %lib_urc;
    my @libraries = $model->libraries;
		my $library_number = 0;
		foreach my $library_name (@libraries) {
				$library_number += 1;
				my $ov_lib_fh = IO::File->new($self->variation_metrics_file_name($library_name));
				unless ($ov_lib_fh) {
					$self->error_message("Unable to get counts for $chromosome $library_name $$");
					return;
				}
				while (<$ov_lib_fh>) {
					chomp;
					unless (/^\d+\s+/) {
						next;
					}
					#RC(A,C,G,T) URC(A,C,G,T) URSC(A,C,G,T) REF Ref(RC,URC,URSC,Q,MQ) Var1(RC,URC,URSC,Q,MQ) Var2(RC,URC,URSC,Q,MQ)
					
					s/\t\t/\t/g;
					my ($lib_chr, $lib_start, $lib_ref_sequence, $lib_iub_sequence, $lib_quality_score,
							$lib_depth, $lib_avg_hits, $lib_high_quality, $lib_unknown,
							$lib_rc_arr, $lib_urc_arr, $lib_urc26_arr, $lib_ursc_arr,
							$lib_ref, $lib_ref_count_arr, , @lib_variant_pair) =
								split("\t");
					my ($lib_ref_rc, $lib_ref_urc, $lib_ref_urc26, $lib_ref_ursc, $lib_ref_bq, $lib_ref_maxbq) =
						split(',',$lib_ref_count_arr);
					$lib_urc{$library_number}{$lib_chr}{$lib_start}{$lib_ref} = $lib_ref_ursc;
					do {
						my $var = shift @lib_variant_pair;
						my $var_count_arr = shift @lib_variant_pair;
						unless (defined($var) && defined($var_count_arr)) {
							last;
						}
						my ($var_rc, $var_urc, $var_urc26, $var_ursc, $var_bq, $var_maxbq) =
							split(',',$var_count_arr);
						$lib_urc{$library_number}{$lib_chr}{$lib_start}{$var} = $var_ursc;
					} while (scalar(@lib_variant_pair));
				}
				$ov_lib_fh->close();
			}

		my $use_validation = 1;
		my $status_file = '/gscmnt/sata180/info/medseq/dlarson/aml_temp_consolidate_08520.csv';
		my %status;
		open(STATUS,$status_file);
		while (<STATUS>) {
			chomp;
			my ($chr, $pos, $status) = split("\t");
			$status ||= '';
			unless ($status =~ /^\s*$/) {
				$status{$chr}{$pos} = $status;
			}
		}
		close(STATUS);




		$file = '/gscmnt/sata180/info/medseq/bshore/amll123t98_annotation/amll123t98_all_SNPs_with_conservation_new.bq.validation.csv';
		my @values_used = ( 2, 3, 4, 28,  5, 6, 10, 11, 37, 39, 41, 33, 9, 60, 63, 64 );
		my $header = new FileHandle;
		$header->open($file, "r") or die "Couldn't open annotation file\n";
		my $header_line = $header->getline; #ignore header
		my $somatic_handle = new FileHandle;
		my $keep_handle = new FileHandle;
        my $keep_highly_supported_handle = new FileHandle;
        my $keep_not_highly_supported_handle = new FileHandle;
		my $remove_handle = new FileHandle;
		my $report_handle = new FileHandle;
		my $invalue_handle = new FileHandle;
		my $somatic_file = $self->somatic_file_name;
        my $keep_file =  $self->keep_file_name;
		my $remove_file = $self->remove_file_name;
        my $report_file = $self->report_file_name;
        my $invalue_file = $self->invalue_file_name;
        my $highly_supported_keep_file = $basename . '.chr' . $chromosome .  '.keep.highlysupported.csv';
        my $not_highly_supported_keep_file = $basename . '.chr' . $chromosome .  '.keep.nothighlysupported.csv';
		$somatic_handle->open("$somatic_file","w") or die "Couldn't open keep output file\n";
		$keep_handle->open("$keep_file","w") or die "Couldn't open keep output file\n";
		$remove_handle->open("$remove_file","w") or die "Couldn't open remove output file\n";
		$report_handle->open("$report_file","w") or die "Couldn't open report output file\n";
		$invalue_handle->open("$invalue_file","w") or die "Couldn't open input value (output) file\n";
		$keep_highly_supported_handle->open("$highly_supported_keep_file","w") or die "Couldn't open keep highly supported output file\n";
		$keep_not_highly_supported_handle->open("$not_highly_supported_keep_file","w") or die "Couldn't open keep not highly supported (output) file\n";
		
		chomp $header_line;
		my $validation_header = '';
#		if ($use_validation) {
#			$validation_header = ',validation_status';
#		}
		print $somatic_handle $header_line . "$validation_header,rule\n";
		print $keep_handle $header_line . "$validation_header,rule\n";
		print $remove_handle $header_line . "$validation_header,rule\n";
	    print $keep_highly_supported_handle $header_line . "$validation_header,rule\n";
        print $keep_not_highly_supported_handle $header_line . "$validation_header,rule\n";
		my %result = ();
		
		#print new header

    # This creates a map file in /tmp which is actually a named pipe
    # streaming the data from the original maps.
    # It can be used only once.  Run this again if you need to use it multiple times.
    #my $ov_cmd = "/gscuser/bshore/src/perl_modules/Genome/Model/Tools/Maq/ovsrc/maqval $map_file_path $snp_file_sort $alignment_quality |";

    my $ov_fh = IO::File->new($self->variation_metrics_file_name());
		unless ($ov_fh) {
			$self->error_message("Unable to get counts $$");
			return;
		}

#		while(my $line=$header->getline) {
#			chomp $line;
#			$line =~ s/NULL/0/g;
#			my @values = split ",", $line;
#			my (
#					$chr,
#					$start,
#					$end,
#					$ref,
#					$var,
##					$ref_type,
##					$var_type,
##					$rgg_id,
##					$ref,
#					$var_read_hg,
#					$var_read_unique_dna_start,
#					$var_read_unique_dna_context,
#					$lib1_al1_read_unique_dna_context,
#					$lib2_al1_read_unique_dna_context,
#					$lib3_al1_read_unique_dna_context,
#					$ref_read_unique_dna_start,
#					$var_read_skin_dna,
#					$qvalue,
#					$base_quality,
#					$max_base_quality
#				 ) = @values[@values_used];
#			my $ref_type = 'ref';
#			my $var_type = 'SNP';
			
		while (<$ov_fh>) {
			chomp;
			unless (/^\d+\s+/) {
				next;
			}
#RC(A,C,G,T) URC(A,C,G,T) URSC(A,C,G,T) REF Ref(RC,URC,URSC,Q,MQ) Var1(RC,URC,URSC,Q,MQ) Var2(RC,URC,URSC,Q,MQ)

			s/\t\t/\t/g;
			my ($chr, $start, $ref_sequence, $iub_sequence, $quality_score,
					$depth, $avg_hits, $high_quality, $unknown,
					$rc_arr, $urc_arr, $urc26_arr, $ursc_arr,
					$ref, $ref_count_arr, @variant_pair) =
						split("\t");
			my ($ref_rc, $ref_urc, $ref_urc26, $ref_ursc, $ref_bq, $ref_maxbq) =
				split(',',$ref_count_arr);
			do {
				my $var = shift @variant_pair;
				my $var_count_arr = shift @variant_pair;
				unless (defined($var) && defined($var_count_arr)) {
					last;
				}
				my ($var_rc, $var_urc, $var_urc26, $var_ursc, $var_bq, $var_maxbq) =
					split(',',$var_count_arr);
				my (
						$end,
						$ref_type,
						$var_type,
						$var_read_hg,
						$var_read_unique_dna_start,
						$var_read_unique_dna_context,
						$lib1_al1_read_unique_dna_context,
						$lib2_al1_read_unique_dna_context,
						$lib3_al1_read_unique_dna_context,
						$ref_read_unique_dna_start,
						$var_read_skin_dna,
						$qvalue,
						$base_quality,
						$max_base_quality
					 ) = 
						 (
							$start,
							'ref',
							'SNP',
							$var_rc,
							$var_urc,
							$var_ursc,
							$lib_urc{1}{$chr}{$start}{$var} || 0,
							$lib_urc{2}{$chr}{$start}{$var} || 0,
							$lib_urc{3}{$chr}{$start}{$var} || 0,
							$ref_urc,
							$normal_href->{$chr}{$start}{$var} || 0,
							$quality_score,
							$var_bq,
							$var_maxbq,
						 );
				my $line = 
					join("\t",
							 (
								$chr,
								$start,
								$end,
								$ref,
								$var,
								$ref_type,
								$var_type,
								$var_read_hg,
								$var_read_unique_dna_start,
								$var_read_unique_dna_context,
								$var_urc26,
								$lib1_al1_read_unique_dna_context,
								$lib2_al1_read_unique_dna_context,
								$lib3_al1_read_unique_dna_context,
								$ref_read_unique_dna_start,
								$var_read_skin_dna,
								$qvalue,
								$base_quality,
								$max_base_quality
							 ));
				
				
				print $invalue_handle join("\t",
																	 (
																		$chr,
																		$start,
																		$end,
																		$ref,
																		$var,
																		$ref_type,
																		$var_type,
																		$var_read_hg,
																		$var_read_unique_dna_start,
																		$var_read_unique_dna_context,
																		$var_urc26,
																		$lib1_al1_read_unique_dna_context,
																		$lib2_al1_read_unique_dna_context,
																		$lib3_al1_read_unique_dna_context,
																		$ref_read_unique_dna_start,
																		$var_read_skin_dna,
																		$qvalue,
																		$base_quality,
																		$max_base_quality
																	 )) . "\n";
				
				my $validation;
				if (exists($status{$chr}{$start})) {
					$validation = $status{$chr}{$start};
				}
				$validation ||= '0';
				my $decision = 'keep';
				my $rule = 'none';
				
				# dtr2a rules
				if ($ruleset eq 'dtr2a') {
					if ($var_read_hg > 9 &&
							$var_read_unique_dna_start <= 4) {
						#Rule 8:
						#    	# of genomic reads supporting variant allele > 9
						#    	# of unique genomic reads supporting variant allele(starting point) <= 4
						#	->  class WT  [93.9%]
						#
						$decision = 'remove';
						$rule = '8';
					} elsif ($ref_read_unique_dna_start > 15) {
						#Rule 14:
						#    	# of unique genomic reads supporting reference allele(starting point) > 15
						#	->  class WT  [89.9%]
						#
						$decision = 'remove';
						$rule = '14';
					} elsif ($ref_read_unique_dna_start <= 15 &&
									 $qvalue < $qvalue_level) {
						# qvalue:
						# 29  is > 74% (74.46%) Specifity (91.06% Sensitivity),
						# 30  is > 75% (74.85%) Specifity (91.06% Sensitivity),
						# 70  is > 90% (90.77%) Specifity (75.50% Sensitivity),
						# 110 is > 95% (95.48%) Specifity (53.31% Sensitivity)
						#Rule 2:
						#    	# of unique genomic reads supporting reference allele(starting point) <= 15
						#    	Maq SNP q-value <= 28
						#	->  class WT  [78.4%]
						#
						$decision = 'remove';
						$rule = '2';
					} elsif ($var_read_unique_dna_start > 4 &&
									 $ref_read_unique_dna_start <= 15 &&
									 $qvalue > 33) {
						#Rule 13:
						#    	# of unique genomic reads supporting variant allele(starting point) > 4
						#    	# of unique genomic reads supporting reference allele(starting point) <= 15
						#    	Maq SNP q-value > 33
						#	->  class G  [88.9%]
						$decision = 'keep';
						$rule = '13';
					} elsif ($var_read_unique_dna_start <= 3 &&
									 $var_read_unique_dna_context > 3  &&
									 $lib1_al1_read_unique_dna_context <= 5 &&
									 $lib2_al1_read_unique_dna_context <= 5 &&
									 $lib3_al1_read_unique_dna_context <= 5
									 #						 $lib1_al1_read_unique_dna_context <= 4 &&
									 #						 $lib2_al1_read_unique_dna_context <= 4 &&
									 #						 $lib3_al1_read_unique_dna_context <= 4
									) {
						#Rule 5:
						#    	# of unique genomic reads supporting variant allele(starting point) <= 3
						#    	# of unique genomic reads supporting variant allele(context) > 3
						#    	# of unique genomic reads supporting reference allele from lib1 in first 26 bp(context) <= 4
						#	->  class WT  [87.1%]
						#
						$decision = 'remove';
						$rule = '5';
						#		} elsif ($var_read_unique_cDNA_start_pre27 <= 9 &&
						#						 $ref_read_unique_dna_start_pre27 > 9) {
						#			#Rule 12:
						#			#    	# of unique cDNA reads supporting variant allele in first 26 bp(starting point) <= 9
						#			#    	# of unique genomic reads supporting reference allele in first 26 bp(starting point) > 9
						#			#	->  class WT  [70.7%]
						#			#
						#			$decision = 'remove';
						#			$rule = '12';
						# Rule 12 removes somatic SNPs--not allowed!!!
					} else {
						#Default class: G
						$decision = 'keep';
						$rule = 'default';
					}
				} elsif ($ruleset eq 'dtr3e') {
					# dtr3e rules
					if ($var_read_unique_dna_start > 7 &&
							$qvalue >= $qvalue_level) {
						#Rule 5:
						#    	# of unique genomic reads supporting variant allele(starting point) > 7
						#	->  class G  [96.8%]
						#
						$decision = 'keep';
						$rule = '5';
						#		} elsif ($var_read_unique_dna_start > 2 &&
						#						 $base_quality <= $bq + 2) {
						#			#Rule 2:
						#			#    	# of unique genomic reads supporting variant allele(starting point) > 2
						#			#    	Base Quality > 18
						#			#	->  class G  [90.7%]
						#			#
						#			$decision = 'keep';
						#			$rule = '2';
					} elsif ($max_base_quality <= 26) {
						#Rule 11:
						#    	Max Base Quality <= 26
						#	->  class WT  [85.2%]
						#
						$decision = 'remove';
						$rule = '11';
					} elsif ($var_read_unique_dna_start <= 7 &&
									 $qvalue < $qvalue_level) {
						#Rule 7:
						#    	# of unique genomic reads supporting variant allele(starting point) <= 7
						#    	Maq SNP q-value <= 29
						#	->  class WT  [81.5%]
						#
						$decision = 'remove';
						$rule = '7';
					} elsif ($var_read_unique_dna_start <= 2) {
						#Rule 8:
						#    	# of unique genomic reads supporting variant allele(starting point) <= 2
						#	->  class WT  [74.7%]
						#
						$decision = 'remove';
						$rule = '8';
					} elsif ($base_quality <= $bq) {
						#Rule 3:
						#    	Base Quality <= 16
						#	->  class WT  [73.0%]
						#
						$decision = 'remove';
						$rule = '3';
					} else {
						#Default class: G
						$decision = 'keep';
						$rule = 'default';
					}
				} else {
					return;
				}
				
				my $output_validation = '';
				if ($use_validation) {
					$result{$decision}{$validation}{n} += 1;
					$result{$decision}{$validation}{rule}{$rule} += 1;
					#				$output_validation = ",$validation";
				}
				if ($decision eq 'keep') {
					if ($var_read_skin_dna == 0 && $var_urc26 > 2) {
						$decision = 'somatic';
					}
				}
				if ($decision eq 'keep') {
					print $keep_handle $line,"$output_validation,$rule\n";    
                    if($var_urc26 > 2) {
                        #print to a highly supported file
                        print $keep_highly_supported_handle $line,"$output_validation,$rule\n";
                    }
                    else {
                        #print to a 'not highly supported file'
                        print $keep_not_highly_supported_handle $line,"$output_validation,$rule\n";
                    }
				} elsif ($decision eq 'somatic') {
					print $somatic_handle $line,"$output_validation,$rule\n";    
					print $keep_handle $line,"$output_validation,$rule\n";    
                    print $keep_highly_supported_handle $line,"$output_validation,$rule\n";
				} else {
					print $remove_handle $line,"$output_validation,$rule\n";    
				}
			} while (scalar(@variant_pair));
		}
		$somatic_handle->close();
		$keep_handle->close();
		$remove_handle->close();
		$invalue_handle->close();
		$header->close();
		$ov_fh->close;
		
		
		
		my $keep_wt = 0;
		my $total_wt = 0;
		my $keep_g = 0;
		my $total_g = 0;
		foreach my $type (sort (keys %result)) {
			print $report_handle "$type\n";
			foreach my $status (sort (keys %{$result{$type}})) {
				my $n = $result{$type}{$status}{n};
				if ($status eq 'WT') {
					$total_wt += $n;
					if ($type eq 'remove') {
						$keep_wt += $n;
					}
				}
				if ($status eq 'G') {
					$total_g += $n;
					if ($type eq 'keep') {
						$keep_g += $n;
					}
				}
				my @rules;
				foreach my $rule_used (sort (keys %{$result{$type}{$status}{rule}})) {
					push @rules, (join(':',($rule_used, $result{$type}{$status}{rule}{$rule_used})));
				}
				print $report_handle "\t" . 
					join("\t",($status,$n,join(',',@rules))) . "\n";
			}
		}
		if ($total_wt > 0) {
			printf $report_handle "Specificity: %0.2f\n", (100.0 * ($keep_wt/$total_wt));
		}
		if ($total_g > 0) {
			printf $report_handle "Sensitivity: %0.2f\n", (100.0 * ($keep_g/$total_g));
		}
		
		$self->generate_figure_3_files($somatic_file);
		# Clean up when we're done...
        #I realize this is dumb to pass refseq. its an incremental refactor and will go away
        #next iteration
        $self->cleanup_my_mapmerge($self->ref_seq_id);
        #commented until we test this method
        #$self->cleanup_all_mapmerges($self->ref_seq_id);
        
		$self->date_completed(UR::Time->now);
		if (0) { # replace w/ actual check
			$self->event_status("Failed");
			return;
		}
		else {
			$self->event_status("Succeeded");
			return 1;
		}
		
	}

1;
        

        

sub generate_figure_3_files {
    my $self = shift;  
    my $somatic_file=shift;

    #this might break
    my $prior = Genome::Model::Event->get(id => $self->prior_event);
    my $snp_file = $prior->snp_report_file;
    #end possible break
    #my $snp_file = $self->_report_file('snp');
        my $dir = $self->model->_filtered_variants_dir();
        if(!defined($dir)) {
            $self->error_message("No filtered_variants directory returned.");
            return undef;
        }
       my $dbsnp_fh = IO::File->new(">$dir" . "/tumor_only_in_d_V_W_" . $self->ref_seq_id .
            ".csv");
       my $dbsnp_count=0;      
       my $non_coding_fh = IO::File->new(">$dir" .
           "/non_coding_tumor_only_variants_" . $self->ref_seq_id .
            ".csv");
       my $non_coding_count=0;      
       my $novel_tumor_fh = IO::File->new(">$dir" .
           "/novel_tumor_only_variants_" . $self->ref_seq_id .
            ".csv");
       my $novel_tumor_count=0;      
       my $silent_fh = IO::File->new(">$dir" .
           "/silent_tumor_only_" . $self->ref_seq_id .
            ".csv");
       my $silent_count=0;     
       my $nonsynonymous_fh = IO::File->new(">$dir" .
           "/non_synonymous_splice_site_variants_" . $self->ref_seq_id .
            ".csv");
       my $nonsynonymous_count=0;      
       my $var_never_manreview_fh = IO::File->new(">$dir" .
           "/var_never_manreview_" . $self->ref_seq_id . ".csv");
       my $never_manreview_count=0;
       my $var_pass_manreview_fh = IO::File->new(">$dir" .
           "/var_pass_manreview_" . $self->ref_seq_id .
            ".csv");
       my $var_pass_manreview_count=0;     
       my $var_fail_manreview_fh = IO::File->new(">$dir" .
           "/var_fail_manreview_" . $self->ref_seq_id .
            ".csv");
       my $var_fail_manreview_count=0;     
       my $var_fail_valid_assay_fh = IO::File->new(">$dir" .
           "/var_fail_valid_assay_" . $self->ref_seq_id .
            ".csv");
       my $var_fail_valid_assay_count=0;      
       my $var_complete_validation_fh = IO::File->new(">$dir" .
           "/var_complete_validation_" . $self->ref_seq_id .
            ".csv");
       my $var_complete_validation_count=0;      
       my $validated_snps_fh = IO::File->new(">$dir" .
           "/valid_snps_" . $self->ref_seq_id .
            ".csv");
       my $validated_snps_count=0;     
       my $false_positives_fh = IO::File->new(">$dir" .
           "/false_positives_" . $self->ref_seq_id .
            ".csv");
       my $false_positives_count=0;     
       my $validated_somatic_var_fh = IO::File->new(">$dir" .
           "/validated_somatic_var_" . $self->ref_seq_id .
            ".csv");
       my $validated_somatic_var_count=0;     
        #added to track things that were passed through manual review but
        #don't have a validation status. Could be pending or could be missing
        #from db
       my $passed_but_no_status_count=0;     
       my $passed_but_no_status_fh = IO::File->new(">$dir" .
           "/passed_manreview_no_validation" . $self->ref_seq_id .
            ".csv");
         my $annotation_fh = IO::File->new($snp_file);
        if(!defined($annotation_fh)) {
            $self->error_message("Could not open report file.");
            return undef;
        }
        my $somatic_fh = IO::File->new($somatic_file);
        if(!defined($somatic_fh)) {
            $self->error_message("Could not open file of somatic mutations.");
            return undef;
        }
        my @cur_somatic_snp;
        my @cur_anno_snp;
        my $anno_line;
        my $somatic_line;
        #throw away header
        $somatic_fh->getline;
        #throw away the header, but preload anno_line so our loop gets off the ground. i rate this hack:medium special
        $anno_line = $annotation_fh->getline;
        #end throw away header section
      while(($somatic_line=$somatic_fh->getline) && defined $anno_line) {
          chomp $somatic_line;
          if (!defined $somatic_line || !defined $anno_line) {
              #the filter file must be over if we're here
              last;
              
          }
          @cur_somatic_snp = split(/\s+/, $somatic_line);
          
          while(!@cur_anno_snp || ($cur_anno_snp[1] < $cur_somatic_snp[1]) ) {
              #we hit this block because a) this is our first time through
              #or b) the last annotation position is smaller than the current somatic snp
              # snp value   
              $anno_line = $annotation_fh->getline;
              chomp $anno_line;
              if(!defined $anno_line) {
                  $self->error_message("Annotation file has ended before somatic file. This may be ok.");
                  $self->error_message("Last somatic snp was\n " . join (" ", @cur_somatic_snp) . "last anno snp was\n " . join(" ", @cur_anno_snp) );
                  last;
              }
              @cur_anno_snp= split (/,/, $anno_line);
          } 
          while($cur_anno_snp[1] == $cur_somatic_snp[1] ) {
          #if we get here then the idea is we have a somatic line with the same position as a snp line.
     
             #call in Brian's somatic file and Eddie's report

             #For Eddie's output we need to know the type of variant and also the
             #dbSNP and Watson/Venter status
             my @report_indexes = (0,1,2,3,5,8,13,16,17,18); 

             #this is taken care of implicitly by the loop actually...damn pair programming
             if(defined($cur_somatic_snp[0]) && defined($cur_anno_snp[0])) {
                 #it's genic and in Eddie's report and passed Brian's filters
                 my ($chromosome, $begin, $end,
                     $variant_allele, $reference_allele, $gene, $variant_type,$dbsnp,
                     $watson, $venter) = @cur_anno_snp[@report_indexes];    

                 #Test if seen in dbSNP or Watson/Venter
                 if((defined($dbsnp) && $dbsnp ne '0') || (defined($watson) && $watson ne '0' ) || (defined($venter) && $venter ne '0')) {
                     #previously identified
                     $self->_write_array_to_file(\@cur_anno_snp, $dbsnp_fh);
                     $dbsnp_count++;
                 }
                 else {
                     $self->_write_array_to_file(\@cur_anno_snp,
                         $novel_tumor_fh);    
                     $novel_tumor_count++;    
                     #nonsynonymous
                     if( $variant_type =~ /missense|nonsense|nonstop|splice_site/i) {
                         #output those that are coding
                         $self->_write_array_to_file(\@cur_anno_snp,
                             $nonsynonymous_fh);
                             $nonsynonymous_count++;

                         my $variant_detail = Genome::VariantReviewDetail->get(
                             chromosome => $chromosome, 
                             begin_position => $begin, 
                             end_position => $end,
                             insert_sequence_allele1 => $variant_allele,
                             delete_sequence => $reference_allele,
                         );
                         if(!defined($variant_detail)) {
                             #try and see if it was a biallelic variant site
                             $variant_detail = Genome::VariantReviewDetail->get(
                                 chromosome => $chromosome, 
                                 begin_position => $begin, 
                                 end_position => $end,
                                 insert_sequence_allele2 => $variant_allele,
                                 delete_sequence => $reference_allele,
                             );
                         }
                         if(defined($variant_detail)) {
                             #it's been sent to manual review
                             my $decision = $variant_detail->pass_manual_review; 
                             #if there is a somatic status then it probably
                             #passed manual review but wasn't documented.
                             #Or it was directly passed along.
                             my $status = $variant_detail->somatic_status;
                             if(defined($decision) && lc($decision) eq 'yes'
                                 || defined($status)) {
                                 $self->_write_array_to_file(\@cur_anno_snp,
                                     $var_pass_manreview_fh);
                                     $var_pass_manreview_count++;

                                 if(defined($status)) {
                                     $status = uc($status);
                                     if($status eq 'S') {
                                         $self->_write_array_to_file(\@cur_anno_snp,
                                         $validated_somatic_var_fh);
                                         $validated_somatic_var_count++;
                                     }
                                     elsif($status eq 'WT') {
                                         $self->_write_array_to_file(\@cur_anno_snp,
                                         $false_positives_fh);
                                         $false_positives_count++;
                                     }
                                     elsif($status eq 'G') {
                                         $self->_write_array_to_file(\@cur_anno_snp,
                                         $validated_snps_fh);
                                         $validated_snps_count++;
                                     }
                                     else {
                                         $self->_write_array_to_file(\@cur_anno_snp, $var_fail_valid_assay_fh);
                                         $var_fail_valid_assay_count++;
                                     }

                                 }
                                 else {
                                     #else no validation status
                                     $passed_but_no_status_count++;     
                                     $self->_write_array_to_file(\@cur_anno_snp, $passed_but_no_status_fh);  
                                 }


                             }
                             else {
                                 #TODO This may not be valid if for instance
                                 #maybe's were passed along to validation
                                 $self->_write_array_to_file(\@cur_anno_snp,
                                     $var_fail_manreview_fh);
                                 $var_fail_manreview_count++;
                             }

                         }
                         else {
                             #we're actually not tracking this case in the
                             #figure
                             #Not in database, but should be!
                             #Either novel or missing from database
                             $never_manreview_count++;
                             $self->_write_array_to_file(\@cur_anno_snp,
                                 $var_never_manreview_fh);
                         }

                     }
                     elsif( $variant_type eq 'silent') {
                         $self->_write_array_to_file(\@cur_anno_snp,
                             $silent_fh);
                             $silent_count++;
                     }
                     else {
                         $self->_write_array_to_file(\@cur_anno_snp,
                             $non_coding_fh);
                             $non_coding_count++;
                     }
                 }
             }

       
     
             $anno_line = $annotation_fh->getline;
             chomp $anno_line;
              if(!defined $anno_line) {
                  #annotation file has ended before somatic one has...this is bad
                  $self->error_message("Annotation file has ended before somatic file. This is probably bad.\n");
                  $self->error_message("Last somatic snp was\n " . @cur_somatic_snp . "last anno snp was\n " . @cur_anno_snp );
                  last;
              }
              @cur_anno_snp= split (/,/, $anno_line);
             
          }
      }
      #close all filehandles.
      my $metric;
      $metric = $self->add_metric(
                                    name=> "somatic_variants_in_d_v_w",
                                    value=> $dbsnp_count,
                                );

      $metric = $self->add_metric(
                                    name=> "non_coding_variants",
                                    value=> $non_coding_count,
                                );


      $metric = $self->add_metric(
                                    name=> "novel_tumor_variants",
                                    value=> $novel_tumor_count,
                                );


      $metric = $self->add_metric(
                                    name=> "silent_variants",
                                    value=> $silent_count,
                                );
      $metric = $self->add_metric(
                                    name=> "nonsynonymous_variants",
                                    value=> $nonsynonymous_count,
                                );


     $metric = $self->add_metric(
                                    name=> "var_pass_manreview",
                                    value=> $var_pass_manreview_count,
                                );


     $metric = $self->add_metric(
                                    name=> "var_fail_manreview",
                                    value=> $var_fail_manreview_count,
                                );
     $metric = $self->add_metric(
                                    name=> "var_fail_valid_assay",
                                    value=> $var_fail_valid_assay_count,
                                );
    $metric = $self->add_metric(
                                    name=> "var_complete_validation",
                                    value=> $var_complete_validation_count,
                                );

    $metric = $self->add_metric(
                                    name=> "validated_snps",
                                    value=> $validated_snps_count,
                                );
    $metric = $self->add_metric(
                                    name=> "false_positives",
                                    value=> $false_positives_count,
                                );
    $metric = $self->add_metric(
                                    name=> "validated_somatic_variants",
                                    value=> $validated_somatic_var_count,
                                );
    $metric = $self->add_metric(
                                    name=> "var_never_sent_to_manual_review",
                                    value=> $never_manreview_count,
                                );
    $metric = $self->add_metric(
                                    name=> "var_pass_manreview_but_no_val_status",
                                    value=> $passed_but_no_status_count,
                                );





      $dbsnp_fh->close;
      $non_coding_fh->close;
      $novel_tumor_fh->close;
      $silent_fh->close;
      $nonsynonymous_fh->close;
      $var_pass_manreview_fh->close;
      $var_fail_manreview_fh->close;
      $var_fail_valid_assay_fh->close;
      $var_complete_validation_fh->close;
      $validated_snps_fh->close;
      $false_positives_fh->close;
      $validated_somatic_var_fh->close;
      $annotation_fh->close;
      $somatic_fh->close;

  }

sub _write_array_to_file {
    my $self=shift;
    my $array_ref_to_write=shift;
    my $file_handle=shift;

    my $line_to_write = join (" ", @{$array_ref_to_write});
    $file_handle->print($line_to_write . "\n");

    return 1;
}
    
#NO! BAD METHOD! THATS A BAD BAD METHOD!
sub _report_file {
    my ($self, $type) = @_;

    return sprintf('%s/%s_report_%s', ($self->model->_reports_dir)[0], $type,$self->ref_seq_id);
}


sub somatic_variants_in_d_v_w {
    my $self = shift;
    my $name = 'somatic_variants_in_d_v_w';
    return $self->get_metric_value($name);
}

sub non_coding_variants {
    my $self = shift;
    my $name = 'non_coding_variants';
    return $self->get_metric_value($name);
}
sub novel_tumor_variants {
    my $self = shift;
    my $name = 'novel_tumor_variants';
    return $self->get_metric_value($name);
}


sub silent_variants {
    my $self = shift;
    my $name = 'silent_variants';
    return $self->get_metric_value($name);
}

sub nonsynonymous_variants {
    my $self = shift;
    my $name = 'nonsynonymous_variants';
    return $self->get_metric_value($name);
}

sub var_pass_manreview {
    my $self = shift;
    my $name = 'var_pass_manreview';
    return $self->get_metric_value($name);
}

sub var_fail_manreview {
    my $self = shift;
    my $name = 'var_fail_manreview';
    return $self->get_metric_value($name);
}


sub var_fail_valid_assay {
    my $self = shift;
    my $name = 'var_fail_valid_assay';
    return $self->get_metric_value($name);
}


sub var_complete_validation {
    my $self = shift;
    my $name = 'var_complete_validation';
    return $self->get_metric_value($name);
}

sub validated_snps {
    my $self = shift;
    my $name = 'validated_snps';
    return $self->get_metric_value($name);
}
sub false_positives {
    my $self = shift;
    my $name = 'false_positives';
    return $self->get_metric_value($name);
}
sub validated_somatic_variants {
    my $self = shift;
    my $name = 'validated_somatic_variants';
    return $self->get_metric_value($name);
}

sub _calculate_somatic_variants_in_d_v_w {
    my $self = shift;
    my $name = 'somatic_variants_in_d_v_w';
    return $self->get_metric_value($name);
}

sub _calculate_non_coding_variants {
    my $self = shift;
    my $name = 'non_coding_variants';
    return $self->get_metric_value($name);
}
sub _calculate_novel_tumor_variants {
    my $self = shift;
    my $name = 'novel_tumor_variants';
    return $self->get_metric_value($name);
}


sub _calculate_silent_variants {
    my $self = shift;
    my $name = 'silent_variants';
    return $self->get_metric_value($name);
}

sub _calculate_nonsynonymous_variants {
    my $self = shift;
    my $name = 'nonsynonymous_variants';
    return $self->get_metric_value($name);
}

sub _calculate_var_pass_manreview {
    my $self = shift;
    my $name = 'var_pass_manreview';
    return $self->get_metric_value($name);
}

sub _calculate_var_fail_manreview {
    my $self = shift;
    my $name = 'var_fail_manreview';
    return $self->get_metric_value($name);
}


sub _calculate_var_fail_valid_assay {
    my $self = shift;
    my $name = 'var_fail_valid_assay';
    return $self->get_metric_value($name);
}


sub _calculate_var_complete_validation {
    my $self = shift;
    my $name = 'var_complete_validation';
    return $self->get_metric_value($name);
}

sub _calculate_validated_snps {
    my $self = shift;
    my $name = 'validated_snps';
    return $self->get_metric_value($name);
}
sub _calculate_false_positives {
    my $self = shift;
    my $name = 'false_positives';
    return $self->get_metric_value($name);
}
sub _calculate_validated_somatic_variants {
    my $self = shift;
    my $name = 'validated_somatic_variants';
    return $self->get_metric_value($name);
}

sub tumor_only_variants {
    my $self = shift;
    my $name = 'tumor_only_variants';
    return $self->get_metric_value($name);
}
sub skin_variants {
    my $self = shift;
    my $name = 'skin_variants';
    return $self->get_metric_value($name);
}

sub well_supported_variants {
    my $self = shift;
    my $name = 'well_supported_variants';
     return $self->get_metric_value($name);
 }

sub _calculate_well_supported_variants {
    my $self = shift;
    my $file_I_will_wordcount_to_find_total_variants = $self->keep_file_name;
    my $file_wordcount_1  = `wc -l $file_I_will_wordcount_to_find_total_variants | cut -f1 -d' '`;
    chomp($file_wordcount_1);
    return $file_wordcount_1;
 }


sub _calculate_tumor_only_variants {
    my $self = shift;
    my $file_I_will_wordcount_to_find_only_tumor_variants = $self->somatic_file_name;
    my $file_wordcount = `wc -l $file_I_will_wordcount_to_find_only_tumor_variants | cut -f1 -d' '`;
    chomp($file_wordcount);
    return $file_wordcount;
}
sub _calculate_skin_variants {
    my $self = shift;
    my $file_I_will_wordcount_to_find_total_variants = $self->keep_file_name;
    my $file_I_will_wordcount_to_find_only_tumor_variants = $self->somatic_file_name;
    my $file_wordcount_1  = `wc -l $file_I_will_wordcount_to_find_total_variants | cut -f1 -d' '`;
    my $file_wordcount_2  = `wc -l $file_I_will_wordcount_to_find_only_tumor_variants | cut -f1 -d' '`;
    chomp($file_wordcount_1);
    chomp($file_wordcount_2);    
    return $file_wordcount_1 - $file_wordcount_2;
}

sub somatic_file_name {
    my $self=shift;
    my $model = $self->model;
    return  $model->_filtered_variants_dir() . "/filtered.chr" . $self->ref_seq_id . '.somatic.csv';
}

sub keep_file_name {
    my $self=shift;
    my $model = $self->model;
    return  $model->_filtered_variants_dir() . "/filtered.chr" . $self->ref_seq_id . '.keep.csv';
}
sub remove_file_name {
    my $self=shift;
    my $model = $self->model;
    return  $model->_filtered_variants_dir() . "/filtered.chr" . $self->ref_seq_id . '.remove.csv';
}

sub report_file_name {
    my $self=shift;
    my $model = $self->model;
    return  $model->_filtered_variants_dir() . "/filtered.chr" . $self->ref_seq_id . '.report.csv';
}

sub invalue_file_name {
    my $self=shift;
    my $model = $self->model;
    return  $model->_filtered_variants_dir() . "/filtered.chr" . $self->ref_seq_id . '.invalue.csv';
}

sub metrics_for_class {
    my $self = shift;
    my @metrics = qw| 
    somatic_variants_in_d_v_w
    non_coding_variants
    novel_tumor_variants
    silent_variants
    nonsynonymous_variants
    var_pass_manreview
    var_fail_manreview
    var_fail_valid_assay
    var_complete_validation
    validated_snps
    false_positives
    validated_somatic_variants
    skin_variants
    tumor_only_variants 
    well_supported_variants
    |;
}


sub variation_metrics_file_name {
     my $self = shift;
     my $library_name = shift;

     my $annotate_step = Genome::Model::Event->get($self->prior_event_id);
     my $post_process_step= Genome::Model::Event->get($annotate_step->prior_event_id);
     
     my $base_variation_file_name = $post_process_step->variation_metrics_file;

     unless($library_name) {
         return $base_variation_file_name;
     }
     return "$base_variation_file_name.$library_name";
} 
     
