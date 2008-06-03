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
        normal_id            => { is => 'Integer', 
                                doc => 'Identifies the normal genome model.' },
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

sub GetNormal {
	my ($self, $ref_seq_file) = shift;
	my $chromosome = $self->ref_seq_id;
	my $model = $self->model;
	my ($detail_file) = $model->_variant_detail_files($chromosome);
	my $normal_name = $self->normal_id;
	my @normal_model = Genome::Model->get(id => $normal_name );
	unless (scalar(@normal_model)) {
		$self->error_message(sprintf("normal model %s does not exist.  please verify this first.",
																 $normal_name));
		return undef;
	}
	my %normal;

	my $map_file_path =
		$normal_model[0]->resolve_accumulated_alignments_filename(
																															ref_seq_id => $chromosome,
																														 );

	my $ov_cmd = "/gscuser/jschindl/ov/test $detail_file $map_file_path |";
	my $ov_fh = IO::File->new($ov_cmd);
	unless ($ov_fh) {
		$self->error_message("Unable to get counts $$");
		return;
	}
	while (<$ov_fh>) {
		chomp;
		my ($chr, $start, $end, $al1, $al2, $al1_type, $al2_type,
				$reference_reads, $variant_reads, $consensus_quality, $read_count,
#				$rgg_id,
				$rc_arr, $urc_arr, $ref,
				$ref_count_arr, $al1_count_arr, $al2_count_arr, $rc) =
					split("\t");
		my ($ref_rc, $ref_urc, $ref_bq, $ref_maxbq) = split(',',$ref_count_arr);
		my ($al1_rc, $al1_urc, $al1_bq, $al1_maxbq) = split(',',$al1_count_arr);
		my ($al2_rc, $al2_urc, $al2_bq, $al2_maxbq) = split(',',$al2_count_arr);
		$normal{$chr}{$start}{ref_rc} = $ref_rc;
		$normal{$chr}{$start}{al1_rc} = $al1_rc;
		$normal{$chr}{$start}{al2_rc} = $al2_rc;
	}
	$ov_fh->close;
	return \%normal;
}

sub GetQuality {
	my ($self) = shift;
	my %quality;
	my $chromosome = $self->ref_seq_id;
	my $model = $self->model;

	my ($snp_file) = $model->_variant_list_files($chromosome);
	my $snp_fh = IO::File->new($snp_file);
	unless ($snp_fh) {
		$self->error_message(sprintf("snp file %s does not exist.  please verify this first.",
																 $snp_file));
		return undef;
	}
	while (<$snp_fh>) {
		chomp;
		my ($id, $start, $ref_sequence, $iub_sequence, $quality_score,
				$depth, $avg_hits, $high_quality, $unknown) = split("\t");
		$quality{$id}{$start}{ref} = $ref_sequence;
		$quality{$id}{$start}{quality} = $quality_score;
	}
	$snp_fh->close;
	return \%quality;
}

sub execute {
    my $self = shift;
    $DB::single = 1; # when debugging, stop here...
    
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

		my $normal_href = $self->GetNormal($ref_seq_file);
		unless (defined($normal_href)) {
			return;
		}

		my $quality_href = $self->GetQuality();
		unless (defined($quality_href)) {
			return;
		}
		
    my ($filtered_list_dir) = $model->_filtered_variants_dir();
    print "$filtered_list_dir\n";
    unless (-d $filtered_list_dir) {
        mkdir $filtered_list_dir;
        `chmod g+w $filtered_list_dir`;
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

#    my @alignments = $model->alignments('-order_by' => ['run_name','run_subset_name']);
#		foreach my $a (@alignments) {
#        my $r = $a->read_set;
#        my $rls = $r->_run_lane_solexa;
#        
#        my $sample_name = $rls->sample_name;
#        my $library_name = $rls->library_name;
#				# This creates a map file in /tmp which is actually a named pipe
#				# streaming the data from the original maps.
#				# It can be used only once.  Run this again if you need to use it multiple times.
#				my $map_file_path = $model->resolve_accumulated_alignments_filename(
#																																						ref_seq_id => $chromosome,
#																																						library_name => $library_name, # optional
#																																					 );
#			}


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
		my $remove_handle = new FileHandle;
		my $report_handle = new FileHandle;
		my $invalue_handle = new FileHandle;
		my $somatic_file = $basename . '.somatic.csv';
		my $keep_file = $basename . '.keep.csv';
		my $remove_file = $basename . '.remove.csv';
		my $report_file = $basename . '.report.csv';
		my $invalue_file = $basename . '.input.csv';
		$somatic_handle->open("$somatic_file","w") or die "Couldn't open keep output file\n";
		$keep_handle->open("$keep_file","w") or die "Couldn't open keep output file\n";
		$remove_handle->open("$remove_file","w") or die "Couldn't open remove output file\n";
		$report_handle->open("$report_file","w") or die "Couldn't open report output file\n";
		$invalue_handle->open("$invalue_file","w") or die "Couldn't open input value (output) file\n";
		
		chomp $header_line;
		my $validation_header = '';
#		if ($use_validation) {
#			$validation_header = ',validation_status';
#		}
		print $somatic_handle $header_line . "$validation_header,rule\n";
		print $keep_handle $header_line . "$validation_header,rule\n";
		print $remove_handle $header_line . "$validation_header,rule\n";
		
		my %result = ();
		
		#print new header

    # This creates a map file in /tmp which is actually a named pipe
    # streaming the data from the original maps.
    # It can be used only once.  Run this again if you need to use it multiple times.
    my $map_file_path = $model->resolve_accumulated_alignments_filename(
																																				ref_seq_id => $chromosome,
#																																				library_name => '031308a', # optional
																																				);

    print "made map $map_file_path\n";

		my $ov_cmd = "/gscuser/jschindl/ov/test $detail_file $map_file_path |";
    my $ov_fh = IO::File->new($ov_cmd);
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
#					$al1,
#					$al2,
##					$al1_type,
##					$al2_type,
##					$rgg_id,
##					$ref,
#					$al2_read_hg,
#					$al2_read_unique_dna_start,
#					$al2_read_unique_dna_context,
#					$lib1_al1_read_unique_dna_context,
#					$lib2_al1_read_unique_dna_context,
#					$lib3_al1_read_unique_dna_context,
#					$al1_read_unique_dna_start,
#					$al2_read_skin_dna,
#					$qvalue,
#					$base_quality,
#					$max_base_quality
#				 ) = @values[@values_used];
#			my $al1_type = 'ref';
#			my $al2_type = 'SNP';
			
		while (<$ov_fh>) {
			chomp;

			my ($chr, $start, $end, $al1, $al2, $al1_type, $al2_type,
					$reference_reads, $variant_reads, $consensus_quality, $read_count,
#					$rgg_id,
					$rc_arr, $urc_arr, $ref,
					$ref_count_arr, $al1_count_arr, $al2_count_arr, $rc) =
						split("\t");
			my ($ref_rc, $ref_urc, $ref_bq, $ref_maxbq) = split(',',$ref_count_arr);
			my ($al1_rc, $al1_urc, $al1_bq, $al1_maxbq) = split(',',$al1_count_arr);
			my ($al2_rc, $al2_urc, $al2_bq, $al2_maxbq) = split(',',$al2_count_arr);
			
			my (
					$al2_read_hg,
					$al2_read_unique_dna_start,
					$al2_read_unique_dna_context,
					$lib1_al1_read_unique_dna_context,
					$lib2_al1_read_unique_dna_context,
					$lib3_al1_read_unique_dna_context,
					$al1_read_unique_dna_start,
					$al2_read_skin_dna,
					$qvalue,
					$base_quality,
					$max_base_quality
				 ) = 
					 (
						$al2_rc,
						$al2_urc,
						0,
						0,
						0,
						0,
						$al1_urc,
						$normal_href->{$chr}{$start}{al2_rc},
						$quality_href->{$chr}{$start}{quality},
						$al2_bq,
						$al2_maxbq,
					 );
			my $line = 
				join("\t",
						 (
							$chr,
							$start,
							$end,
							$al1,
							$al2,
							$al1_type,
							$al2_type,
							$al2_read_hg,
							$al2_read_unique_dna_start,
							$al2_read_unique_dna_context,
							$lib1_al1_read_unique_dna_context,
							$lib2_al1_read_unique_dna_context,
							$lib3_al1_read_unique_dna_context,
							$al1_read_unique_dna_start,
							$al2_read_skin_dna,
							$qvalue,
							$base_quality,
							$max_base_quality
						 ));

			
			print $invalue_handle join("\t",
																 (
																	$chr,
																	$start,
																	$end,
																	$al1,
																	$al2,
																	$al1_type,
																	$al2_type,
																	$al2_read_hg,
																	$al2_read_unique_dna_start,
																	$al2_read_unique_dna_context,
																	$lib1_al1_read_unique_dna_context,
																	$lib2_al1_read_unique_dna_context,
																	$lib3_al1_read_unique_dna_context,
																	$al1_read_unique_dna_start,
																	$al2_read_skin_dna,
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
				if ($al2_read_hg > 9 &&
						$al2_read_unique_dna_start <= 4) {
					#Rule 8:
					#    	# of genomic reads supporting variant allele > 9
					#    	# of unique genomic reads supporting variant allele(starting point) <= 4
					#	->  class WT  [93.9%]
					#
					$decision = 'remove';
					$rule = '8';
				} elsif ($al1_read_unique_dna_start > 15) {
					#Rule 14:
					#    	# of unique genomic reads supporting reference allele(starting point) > 15
					#	->  class WT  [89.9%]
					#
					$decision = 'remove';
					$rule = '14';
				} elsif ($al1_read_unique_dna_start <= 15 &&
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
				} elsif ($al2_read_unique_dna_start > 4 &&
								 $al1_read_unique_dna_start <= 15 &&
								 $qvalue > 33) {
					#Rule 13:
					#    	# of unique genomic reads supporting variant allele(starting point) > 4
					#    	# of unique genomic reads supporting reference allele(starting point) <= 15
					#    	Maq SNP q-value > 33
					#	->  class G  [88.9%]
					$decision = 'keep';
					$rule = '13';
				} elsif ($al2_read_unique_dna_start <= 3 &&
								 $al2_read_unique_dna_context > 3  &&
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
					#		} elsif ($al2_read_unique_cDNA_start_pre27 <= 9 &&
					#						 $al1_read_unique_dna_start_pre27 > 9) {
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
				if ($al2_read_unique_dna_start > 7 &&
						$qvalue >= $qvalue_level) {
					#Rule 5:
					#    	# of unique genomic reads supporting variant allele(starting point) > 7
					#	->  class G  [96.8%]
					#
					$decision = 'keep';
					$rule = '5';
					#		} elsif ($al2_read_unique_dna_start > 2 &&
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
				} elsif ($al2_read_unique_dna_start <= 7 &&
								 $qvalue < $qvalue_level) {
					#Rule 7:
					#    	# of unique genomic reads supporting variant allele(starting point) <= 7
					#    	Maq SNP q-value <= 29
					#	->  class WT  [81.5%]
					#
					$decision = 'remove';
					$rule = '7';
				} elsif ($al2_read_unique_dna_start <= 2) {
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
				if ($al2_read_skin_dna == 0) {
					$decision = 'somatic';
				}
			}
			if ($decision eq 'keep') {
				print $keep_handle $line,"$output_validation,$rule\n";    
			} elsif ($decision eq 'somatic') {
				print $somatic_handle $line,"$output_validation,$rule\n";    
				print $keep_handle $line,"$output_validation,$rule\n";    
			} else {
				print $remove_handle $line,"$output_validation,$rule\n";    
			}
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
		
		# Clean up when we're done...
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

