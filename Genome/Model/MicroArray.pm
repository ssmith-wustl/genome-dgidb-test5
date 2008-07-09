
package Genome::Model::MicroArray;

use strict;
use warnings;

use above "Genome";
use GSCApp;
use File::Basename;
use Sort::Naturally;

class Genome::Model::MicroArray{
    is => 'Genome::Model',
    has => [
        snp_file                        => { is     => 'String', 
                                             doc    => 'A single snp file containing data for all chromosomes. This will be refactored to run on one per chromosome as well.',   
        },
#        snp_directory                   => { is     => 'String', 
#                                             doc    => 'The directory where the files "snip_1" through "snip_y" are located.',   
#        },
        affy_illumina_intersection_file => { is     => 'String', 
                                             doc    => 'The file representing the intersection of where affy and illumina data agrees. Must be pre-existing. Will be refactored to create this.',   
        },
# will probably remove this
        base_name                       => { is     => 'String', 
                                             doc    => 'The base name of the files produced.',   
        },

    ],
    has_optional => [
        new_intersection_file           => { is     => 'String', 
                                             doc    => 'The location of the output file of the affy and illumina intersection.',   
        },
        # Since we do not know where the below files are, for now just use the intersection file...        
        affy_file                      => { is     => 'String', 
                                            doc    => 'The .cns consensus file from maq to compare to the microarray data.',   
        },
        illumina_file                  => { is     => 'String', 
                                            doc    => 'The .cns consensus file from maq to compare to the microarray data.',   
        },
    ]
};

# This stuff is hacked out of brian's maq_gold_snp.pl script
sub execute {
    my $self = shift;
    
    # Command line option variables
    my($aii_file, $cns, $basename, $maxsnps, $snplist);
    $maxsnps=10000000;
    $snplist = 0;

    $aii_file = $self->affy_illumina_intersection_file();
    $basename = $self->base_name();
#    my $snp_directory = $self->snp_file();
    my $big_snip = $self->snp_file();

    #
    ## The main part of the program starts here.
    #

        my ($total_aii, $ref_aii, $het_aii, $hom_aii);
        $total_aii = $ref_aii = $het_aii = $hom_aii = 0;
        my %aii;
        open(AII,$aii_file) || die "Unable to open aii input file: $aii_file $$";
        while(<AII>) {
            chomp;
            my $line = $_;
            my ($chromosome, $start, $end, $allele1, $allele2
                    , $rgg1_allele1_type, $rgg1_allele2_type
                    , $rgg2_allele1_type, $rgg2_allele2_type
                 ) = split("\t");

            my $ref = 0;
            $total_aii += 1;
            if ($rgg1_allele1_type eq 'ref' &&
                    $rgg1_allele2_type eq 'ref' &&
                    $rgg2_allele1_type eq 'ref' &&
                    $rgg2_allele2_type eq 'ref') {
                $ref_aii += 1;
                $ref = 1;
            }
            
            $aii{$chromosome}{$start}{allele1} = $allele1;
            $aii{$chromosome}{$start}{allele2} = $allele2;
            $aii{$chromosome}{$start}{ref} = $ref;
            $aii{$chromosome}{$start}{found} = 0;
            $aii{$chromosome}{$start}{line} = $line;

            if ($rgg1_allele1_type eq 'ref' &&
                    $rgg1_allele2_type eq 'ref' &&
                    $rgg2_allele1_type eq 'ref' &&
                    $rgg2_allele2_type eq 'ref') {
                next;
            }
            if ($allele1 eq $allele2) {
                $hom_aii += 1;
            } else {
                $het_aii += 1;
            }
        }
        close(AII);

        
#        unless(open(SNP, $big_snip)) {
#        my $snp_cmd = "sort $snp_directory/snip_* |";
        my $snp_cmd = $big_snip;
        unless (open(SNP,$snp_cmd)) {
            die("Unable to open snp file");
            exit 0;
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

        my $max_bin = 40;
        my %qsnp;
        my %qsnp_het;
        my %qsnp_het_match;
        my %qsnp_het_ref_match;
        my %qsnp_het_var_match;
        my %qsnp_het_mismatch;
        my %qsnp_hom;
        my %qsnp_hom_match;
        my %qsnp_hom_mismatch;
        my $total;
        my $output_snplist = $basename . '_snplist.csv';
        if ($snplist) {
            open(SNPLIST,">$output_snplist") || die "Unable to create snp list file: $output_snplist $$";
        }
        while(<SNP>) {
            chomp;
            my ($id, $start, $ref_sequence, $iub_sequence, $quality_score, $depth, $avg_hits, $high_quality, $unknown) = split("\t");
            next if ($depth < 2);
            $total += 1;
            if ($total >= $maxsnps) {
                last;
            }

            my ($chr, $pos, $offset, $c_orient);
            ($chr, $pos) = ($id, $start);

            my $genotype = $IUBcode{$iub_sequence};
            $genotype ||= 'NN';
            my $cns_sequence = substr($genotype,0,1);
            my $var_sequence = (length($genotype) > 2) ? 'X' : substr($genotype,1,1);
            if (exists($aii{$chr}{$pos})) {
                $aii{$chr}{$pos}{found} = 1;
                $qsnp{$quality_score} += 1;
                if ($aii{$chr}{$pos}{allele1} ne $aii{$chr}{$pos}{allele2}) {
                    $qsnp_het{$quality_score} += 1;
                    if (($aii{$chr}{$pos}{allele1} eq $cns_sequence &&
                             $aii{$chr}{$pos}{allele2} eq $var_sequence) ||
                            ($aii{$chr}{$pos}{allele1} eq $var_sequence &&
                             $aii{$chr}{$pos}{allele2} eq $cns_sequence)) {
                        $qsnp_het_match{$quality_score} += 1;
                        $qsnp_het_ref_match{$quality_score} += 1;
                        $qsnp_het_var_match{$quality_score} += 1;
                        if ($snplist) {
                            print SNPLIST join("\t",('het',$chr,$pos,
                                                                             $cns_sequence,$var_sequence,
                                                                             $quality_score,$depth)) . "\n";
                        }
                    } else {
                        if ($aii{$chr}{$pos}{allele1} eq $cns_sequence ||
                                $aii{$chr}{$pos}{allele1} eq $var_sequence) {
                            $qsnp_het_ref_match{$quality_score} += 1;
                            if ($snplist) {
                                print SNPLIST join("\t",('hetref',$chr,$pos,
                                                                                 $cns_sequence,$var_sequence,
                                                                                 $quality_score,$depth)) . "\n";
                            }
                        } elsif ($aii{$chr}{$pos}{allele2} eq $cns_sequence ||
                                $aii{$chr}{$pos}{allele2} eq $var_sequence) {
                            $qsnp_het_var_match{$quality_score} += 1;
                            if ($snplist) {
                                print SNPLIST join("\t",('hetvar',$chr,$pos,
                                                                                 $cns_sequence,$var_sequence,
                                                                                 $quality_score,$depth)) . "\n";
                            }
                        } else {
                            if ($snplist) {
                                print SNPLIST join("\t",('hetmis',$chr,$pos,
                                                                                 $cns_sequence,$var_sequence,
                                                                                 $quality_score,$depth)) . "\n";
                            }
                        }
                        $qsnp_het_mismatch{$quality_score} += 1;
                    }
                } else {
                    $qsnp_hom{$quality_score} += 1;
                    if (($aii{$chr}{$pos}{allele1} eq $cns_sequence &&
                             $aii{$chr}{$pos}{allele2} eq $var_sequence) ||
                            ($aii{$chr}{$pos}{allele1} eq $var_sequence &&
                             $aii{$chr}{$pos}{allele2} eq $cns_sequence)) {
                        $qsnp_hom_match{$quality_score} += 1;
                        if ($snplist) {
                            my $type = ($aii{$chr}{$pos}{ref}) ? 'ref' : 'hom';
                            print SNPLIST join("\t",($type,$chr,$pos,
                                                                             $cns_sequence,$var_sequence,
                                                                             $quality_score,$depth)) . "\n";
                        }
                    } else {
                            if ($snplist) {
                                print SNPLIST join("\t",('hommis',$chr,$pos,
                                                                                 $cns_sequence,$var_sequence,
                                                                                 $quality_score,$depth)) . "\n";
                            }
                        $qsnp_hom_mismatch{$quality_score} += 1;
                    }
                }
            }
        }
        close(SNPLIST);
        close(SNP);

        my $output_notfound = $basename . '_notfound.csv';
        open(NOTFOUND,">$output_notfound") || die "Unable to create not found file: $output_notfound $$";
        foreach my $chromosome (sort (keys %aii)) {
            foreach my $location (sort (keys %{$aii{$chromosome}})) {
                unless ($aii{$chromosome}{$location}{found}) {
                    print NOTFOUND $aii{$chromosome}{$location}{line} . "\n";
                }
            }
        }

        close(NOTFOUND);

        my $output = $basename . '_detail.csv';
        open(OUTPUT,">$output") || die "Unable to open output file: $output";
        print OUTPUT "Total\t$total\n\n";
            print OUTPUT "qval\tall_het\thet_match\thet_mismatch\tall\tall_hom\thom_match\thom_mismatch\thet_ref_match\thet_var_match\n";
        my @qkeys = ( 0, 10, 15, 20, 30 );
        my %all;
        my %het_location;
        my %het_match;
        my %het_ref_match;
        my %het_var_match;
        my %het_mismatch;
        my %hom_location;
        my %hom_match;
        my %hom_mismatch;
        foreach my $qval (sort { $a <=> $b } (keys %qsnp)) {
            # Initialize values to 0 if undef
            my $all = $qsnp{$qval} || 0;
            my $all_het = $qsnp_het{$qval} || 0;
            my $het_match = $qsnp_het_match{$qval} || 0;
            my $het_ref_match = $qsnp_het_ref_match{$qval} || 0;
            my $het_var_match = $qsnp_het_var_match{$qval} || 0;
            my $het_mismatch = $qsnp_het_mismatch{$qval} || 0;
            my $all_hom = $qsnp_hom{$qval} || 0;
            my $hom_match = $qsnp_hom_match{$qval} || 0;
            my $hom_mismatch = $qsnp_hom_mismatch{$qval} || 0;
            print OUTPUT "$qval\t$all_het\t$het_match\t$het_mismatch\t$all\t$all_hom\t$hom_match\t$hom_mismatch\t$het_ref_match\t$het_var_match\n";
            foreach my $qkey (@qkeys) {
                if ($qval >= $qkey) {
                    $all{$qkey} += $all;
                    $het_location{$qkey} += $all_het;
                    $het_match{$qkey} += $het_match;
                    $het_ref_match{$qkey} += $het_ref_match;
                    $het_var_match{$qkey} += $het_var_match;
                    $het_mismatch{$qkey} += $het_mismatch;
                    $hom_location{$qkey} += $all_hom;
                    $hom_match{$qkey} += $hom_match;
                    $hom_mismatch{$qkey} += $hom_mismatch;
                }
            }
        }
        close(OUTPUT);

        my $summary = $basename . '_summary.csv';
        open(SUMMARY,">$summary") || die "Unable to open output summary file: $summary";
        print SUMMARY "Total\t$total\n\n";
        print SUMMARY "QVAL\tHet_Location\tHet_Match\tHet_Mismatch\tHom_Location\tHom_Match\tHom_Mismatch\tAll\tHet_Ref_Match\tHet_Var_Match\n";
        foreach my $qkey (@qkeys) {
            print SUMMARY "$qkey\t$het_location{$qkey}\t$het_match{$qkey}\t$het_mismatch{$qkey}\t$hom_location{$qkey}\t$hom_match{$qkey}\t$hom_mismatch{$qkey}\t$all{$qkey}\t$het_ref_match{$qkey}\t$het_var_match{$qkey}\n";
        }
        close(SUMMARY);

        my $report = $basename . '_report.csv';
        open(REPORT,">$report") || die "Unable to open output report file: $report";
        my ($result) = $self->GetResults($summary);

        print REPORT "all\tref\thet\thom\n";
        print REPORT "$total_aii\t$ref_aii\t$het_aii\t$hom_aii\n";

        print REPORT "\nTotal: " . $result->{total} . "\n\n";

        print REPORT "Heterozygous:\n";
        print REPORT join("\t", ( '', 'Location', 'Match', 'Ref Match', 'Var Match',
                                             'Mismatch')) . "\n";

        print REPORT "SNP Q0:\t" . 
            join("\t",@{$result}{ qw(
                                                             q0_location q0_match q0_ref_match q0_var_match q0_mismatch
                                                            )
                                                    }) . "\n";
        print REPORT "SNP Q15:\t" . 
            join("\t",@{$result}{ qw(
                                                             q15_location q15_match q15_ref_match q15_var_match q15_mismatch
                                                            )
                                                    }) . "\n";
        print REPORT "SNP Q30:\t" . 
            join("\t",@{$result}{ qw(
                                                             q30_location q30_match q30_ref_match q30_var_match q30_mismatch
                                                            )
                                                    }) . "\n";

        print REPORT "SNP Q0 %:\t" . 
            join("\t",
                     map { my $p = sprintf "%0.2f%%", (100.0 * $_)/$het_aii; $p; }
                     @{$result}{ qw(
                                                    q0_location q0_match q0_ref_match q0_var_match q0_mismatch
                                                 )
                                         }) . "\n";
        print REPORT "SNP Q15 %:\t" . 
            join("\t",
                     map { my $p = sprintf "%0.2f%%", (100.0 * $_)/$het_aii; $p; }
                     @{$result}{ qw(
                                                    q15_location q15_match q15_ref_match q15_var_match q15_mismatch
                                                 )
                                         }) . "\n";
        print REPORT "SNP Q30 %:\t" . 
            join("\t",
                     map { my $p = sprintf "%0.2f%%", (100.0 * $_)/$het_aii; $p; }
                     @{$result}{ qw(
                                                    q30_location q30_match q30_ref_match q30_var_match q30_mismatch
                                                 )
                                         }) . "\n";

        print REPORT "\nHomozygous:\n";
        print REPORT join("\t", ( '', 'Location', 'Match', 'Mismatch')) . "\n";
        print REPORT "SNP Q0:\t" . 
            join("\t",@{$result}{ qw(
                                                             q0_location_hom q0_match_hom q0_mismatch_hom
                                                            )
                                                    }) . "\n";
        print REPORT "SNP Q15:\t" . 
            join("\t",@{$result}{ qw(
                                                             q15_location_hom q15_match_hom q15_mismatch_hom
                                                            )
                                                    }) . "\n";
        print REPORT "SNP Q30:\t" . 
            join("\t",@{$result}{ qw(
                                                             q30_location_hom q30_match_hom q30_mismatch_hom
                                                            )
                                                    }) . "\n";

        print REPORT "SNP Q0 %:\t" . 
            join("\t",
                     map { my $p = sprintf "%0.2f%%", (100.0 * $_)/$het_aii; $p; }
                     @{$result}{ qw(
                                                    q0_location_hom q0_match_hom q0_mismatch_hom
                                                 )
                                         }) . "\n";
        print REPORT "SNP Q15 %:\t" . 
            join("\t",
                     map { my $p = sprintf "%0.2f%%", (100.0 * $_)/$het_aii; $p; }
                     @{$result}{ qw(
                                                    q15_location_hom q15_match_hom q15_mismatch_hom
                                                 )
                                         }) . "\n";
        print REPORT "SNP Q30 %:\t" . 
            join("\t",
                     map { my $p = sprintf "%0.2f%%", (100.0 * $_)/$het_aii; $p; }
                     @{$result}{ qw(
                                                    q30_location_hom q30_match_hom q30_mismatch_hom
                                                 )
                                         }) . "\n";
#		print Dumper ($result);
        close(REPORT);

        my $numbers = $basename . '_numbers.csv';
        open(NUMBERS,">$numbers") || die "Unable to open output report file: $numbers ";

        # 
        my $ref_match = $result->{q15_ref_match};  
        my $var_match = $result->{q15_var_match};  
        my $all_match = $result->{q15_match};  
        print NUMBERS "HQ SNP count (all het snps): $het_aii\n";
        print NUMBERS "HQ SNP reference allele count (agree on ref): $ref_match\n";
        print NUMBERS "HQ SNP variant allele count (agree on var): $var_match\n";
        print NUMBERS "HQ SNP both allele count (total agreement): $all_match\n";
        
        close(NUMBERS);
        
        return 1;
}

# This is also fully pasted from the maq_gold_snp.
sub GetResults {
    my $self = shift;
    
	my ($summary_file) = @_;
	my $filename = basename($summary_file);

	open(SUMMARY,$summary_file) || die "Unable to open summary file: $summary_file $$";
	my %result_best_fit;
	my %new_best_fit;
	my $total;
	while(<SUMMARY>) {
		chomp;
		my ($qkey, $het_location, $het_match, $het_mismatch,
				$hom_location, $hom_match, $hom_mismatch, $all,
				$het_ref_match, $het_var_match) = split("\t");
        $qkey = $qkey || ''; #FIXME : cheap fix to get rid of warnings here        
		if ($qkey eq 'Total') {
			$total = $het_location;
			$total ||= '';
			if (!defined($total) || $total eq '') {
				return (\%new_best_fit);
			}
		} elsif ($qkey =~ /^\d+$/x) {
#			print "$_\n";
			$result_best_fit{$qkey}{location} = $het_location;
			$result_best_fit{$qkey}{match} = $het_match;
			$result_best_fit{$qkey}{ref_match} = $het_ref_match;
			$result_best_fit{$qkey}{var_match} = $het_var_match;
			$result_best_fit{$qkey}{mismatch} = $het_mismatch;
			$result_best_fit{$qkey}{location_hom} = $hom_location;
			$result_best_fit{$qkey}{match_hom} = $hom_match;
			$result_best_fit{$qkey}{mismatch_hom} = $hom_mismatch;
		} else {
#			print "$_\n";
		}
	}
	close(SUMMARY);
	$new_best_fit{total} = $total || 0;
	$new_best_fit{q0_location} = $result_best_fit{0}{location} || 0;
	$new_best_fit{q0_match} = $result_best_fit{0}{match} || 0;
	$new_best_fit{q0_ref_match} = $result_best_fit{0}{ref_match} || 0;
	$new_best_fit{q0_var_match} = $result_best_fit{0}{var_match} || 0;
	$new_best_fit{q0_mismatch} = $result_best_fit{0}{mismatch} || 0;
	$new_best_fit{q0_location_hom} = $result_best_fit{0}{location_hom} || 0;
	$new_best_fit{q0_match_hom} = $result_best_fit{0}{match_hom} || 0;
	$new_best_fit{q0_mismatch_hom} = $result_best_fit{0}{mismatch_hom} || 0;

	$new_best_fit{q15_location} = $result_best_fit{15}{location} || 0;
	$new_best_fit{q15_match} = $result_best_fit{15}{match} || 0;
	$new_best_fit{q15_ref_match} = $result_best_fit{15}{ref_match} || 0;
	$new_best_fit{q15_var_match} = $result_best_fit{15}{var_match} || 0;
	$new_best_fit{q15_mismatch} = $result_best_fit{15}{mismatch} || 0;
	$new_best_fit{q15_location_hom} = $result_best_fit{15}{location_hom} || 0;
	$new_best_fit{q15_match_hom} = $result_best_fit{15}{match_hom} || 0;
	$new_best_fit{q15_mismatch_hom} = $result_best_fit{15}{mismatch_hom} || 0;

	$new_best_fit{q30_location} = $result_best_fit{30}{location} || 0;
	$new_best_fit{q30_match} = $result_best_fit{30}{match} || 0;
	$new_best_fit{q30_ref_match} = $result_best_fit{30}{ref_match} || 0;
	$new_best_fit{q30_var_match} = $result_best_fit{30}{var_match} || 0;
	$new_best_fit{q30_mismatch} = $result_best_fit{30}{mismatch} || 0;
	$new_best_fit{q30_location_hom} = $result_best_fit{30}{location_hom} || 0;
	$new_best_fit{q30_match_hom} = $result_best_fit{30}{match_hom} || 0;
	$new_best_fit{q30_mismatch_hom} = $result_best_fit{30}{mismatch_hom} || 0;
	return (\%new_best_fit);
}

# Sort a file, return its sorted name
# This must be used on the affy and illumina files since they seem to come unsorted...
# We want to sort by chromosome and then position
sub sort_affy_file {
    my ($self, $file) = @_;

    # These are hardcoded values for now... this is the way affy files should always be laid out...
    my $chromosome_column_num = 2;
    my $position_column_num = 3;

    my $input_file_name = $file;
    #FIXME my $output_file_name = $file . "_sorted";
    my $output_file_name = '/gscuser/gsanders/aml/affy_sorted';
    
    # TODO: Grab the header then copy over the rest of the file so the header doesnt get sorted in
    # count the lines, pipe all of them minus the header to sort...
    my $lines = `wc -l $input_file_name`;
    $lines -=2; # so we do not capture the header
    system("head -1 $input_file_name > $output_file_name");
    
    # Sort by chromosome and position assume a tsv file since thats the way illumina rolls... 
    system("tail -$lines $input_file_name | sort -g -t ',' -k $chromosome_column_num -k $position_column_num >> $output_file_name");

    return $output_file_name;
}

# Version of the above to handle illumina files
sub sort_illumina_file {
    my ($self, $file) = @_;
    
    # These are hardcoded values for now... this is the way affy files should always be laid out...
    my $chromosome_column_num = 16;
    my $position_column_num = 17;

    my $input_file_name = $file;
    #FIXME my $output_file_name = $file . "_sorted";
    my $output_file_name = '/gscuser/gsanders/aml/illumina_sorted';

    # TODO: Grab the header then copy over the rest of the file so the header doesnt get sorted in
    # count the lines, pipe all of them minus the header to sort...
    my $lines = `wc -l $input_file_name`;
    $lines--; # so we do not capture the header
    system("head -1 $input_file_name > $output_file_name");
    
    # Sort by chromosome and position assume a tsv file since thats the way illumina rolls... 
    system("tail -$lines $input_file_name | sort -g -t \$'\t' -k $chromosome_column_num -k $position_column_num >> $output_file_name");

    return $output_file_name;
}

# Experimental sort for genotype submission files (sort by chromosome and position)
# This uses a bunch of magic that I do not fully understand. I may be opening pandora's box.
sub sort_genotype_submission_file {
    my ($self, $file) = @_;

    # Begin black magic
    open (DATA, $file); 
    my @list= <DATA>;
    my @sorted= @list[
    map { unpack "N", substr($_,-4) }
    sort
    map {
        my $key= $list[$_];
        $key =~ s[(\d+)][ pack "N", $1 ]ge;
        $key . pack "N", $_
    } 0..$#list
    ];
    
    # Open the output file and dump the sorted stuff
#    my $output_file_name = $file . "_sorted";
    my @file_split = split('/',$file);
    my $output_file_name = "/gscuser/gsanders/aml/" . $file_split[-1] . "_sorted";
    
    my $output_fh = IO::File->new(">$output_file_name");
    print $output_fh @sorted;

    return $output_file_name;
}

# Compare files and output where they agree on chromosome, position, and alleles into a 3rd file
# This assumes the files are unsorted with only one header line on top (a requirement of the parser)
sub Xmake_affy_illumina_intersection {
    my $self = shift;

    my $output_file_name = $self->new_intersection_file();
    my $output_fh;
    unless ($output_fh = IO::File->new(">$output_file_name")) {
        die("Could not open $output_file_name");
    }

    my $illumina_file_unsorted = $self->illumina_file;
    my $affy_file_unsorted = $self->affy_file;

    my $illumina_file = $self->sort_illumina_file($illumina_file_unsorted);
    my $affy_file = $self->sort_affy_file($affy_file_unsorted);

    # Hardcoded values for the names of the columns for the illumina and affy files
    # FIXME: make sure these are correct...
    my $illumina_file_chrom_column = 'Chr';
    my $illumina_file_pos_column = 'Position';
    my $illumina_file_allele_1_column = 'Allele1 - Top';
    my $illumina_file_allele_2_column = 'Allele2 - Top';
    my $affy_file_chrom_column = 'chrom';
    my $affy_file_pos_column = 'pos'; 
    my $affy_file_allele_1_column = 'allel1';
    my $affy_file_allele_2_column = 'allel2';  
    
    # Create the parsers... right now we assume the file just has a header line and then data
    # This assumes they are tab delimited... should probably be ANOTHER parameter...
    my $illumina_file_parser = Genome::Utility::Parser->create(
                                                  file => $illumina_file,
                                                  separator => "\t",
                                                  );
    my $affy_file_parser = Genome::Utility::Parser->create(
                                                  file => $affy_file,
                                                  separator => ",",
                                                  );

    my $affy_file_line;    
    while(my $illumina_file_line = $illumina_file_parser->getline) {
        if (!defined $illumina_file_line) {
            # file 1 must be over if we're here
            last;
        }

        while(!$affy_file_line || ($affy_file_line->{$affy_file_pos_column} < $illumina_file_line->{$illumina_file_pos_column}) ) {
            # we hit this block because a) this is our first time through
            # or b) the last file 1 position is smaller than the current file 2 position
            $affy_file_line = $affy_file_parser->getline;
            if(!defined $affy_file_line) {
                # file 2 must be over if we're here
                last;
            }
        }
        
        if (!defined $affy_file_line) {
            # file 2 must be over if we're here
            last;
        }
        # If we get here, check to make sure the positions are equal and
        # check the alleles and copy to third file if they match
        if (($illumina_file_line->{$illumina_file_allele_1_column} eq $affy_file_line->{$illumina_file_allele_1_column}) && 
            ($illumina_file_line->{$illumina_file_allele_2_column} eq $affy_file_line->{$illumina_file_allele_2_column}) &&
            ($illumina_file_line->{$illumina_file_pos_column} eq $affy_file_line->{$affy_file_pos_column}) &&
            ($illumina_file_line->{$illumina_file_chrom_column} eq $affy_file_line->{$affy_file_chrom_column})) {
            # Shouldnt matter which one we write to the file
            # For now, write in an output identical to the current intersection files
            # FIXME: BIG ASSUMPTIONS:
            # 1. position start and end are always the same since its just a single position...
            # 2. Print SNP SNP if homo... print ref SNP if het...
            # 3. Print this series yet AGAIN for some reason
            print $output_fh $illumina_file_line->{$illumina_file_chrom_column} . "\t" .
                             $illumina_file_line->{$illumina_file_pos_column} . "\t" .
                             $illumina_file_line->{$illumina_file_pos_column} . "\t" .
                             $illumina_file_line->{$illumina_file_allele_1_column} . "\t" .
                             $illumina_file_line->{$illumina_file_allele_2_column} . "\t";
            # as per the assumption, if it is het print "ref SNP ref SNP"... otherwise SNP SNP SNP SNP
            if ($illumina_file_line->{$illumina_file_allele_1_column} eq $illumina_file_line->{$illumina_file_allele_2_column}) {
                print $output_fh "ref\tSNP\tref\tSNP\n"; 
            } else {
                print $output_fh "SNP\tSNP\tSNP\tSNP\n"; 
            }
        }
    }
    $output_fh->close;

    return 1;
}

# Compare files and output where they agree on chromosome, position, and alleles into a 3rd file
# This assumes the files are unsorted with only one header line on top (a requirement of the parser)
# version utilizing genotype submission files...
sub make_affy_illumina_intersection {
    my $self = shift;

    my $output_file_name = $self->new_intersection_file();
    my $output_fh;
    unless ($output_fh = IO::File->new(">$output_file_name")) {
        die("Could not open $output_file_name");
    }

    my $illumina_file_unsorted = $self->illumina_file;
    my $affy_file_unsorted = $self->affy_file;

    my $illumina_file = $self->sort_genotype_submission_file($illumina_file_unsorted);
    my $affy_file = $self->sort_genotype_submission_file($affy_file_unsorted);

    my $illumina_file_fh;
    unless($illumina_file_fh = IO::File->new($illumina_file)) {
        die("Could not open $illumina_file");
    }
    my $affy_file_fh;
    unless($affy_file_fh = IO::File->new($affy_file)) {
        die("Could not open $affy_file");
    }

    my ($affy_file_line, $affy_chrom, $affy_pos, $affy_ref, $affy_allele_1, $affy_allele_2)
        = $self->parse_new_line($affy_file_fh);
    my ($illumina_file_line, $illumina_chrom, $illumina_pos, $illumina_ref, $illumina_allele_1, $illumina_allele_2)
        = $self->parse_new_line($illumina_file_fh);
    
    while($illumina_file_line && $affy_file_line) {
        #compare chromosomes
        if(ncmp($illumina_chrom, $affy_chrom) > 0) {
            ($affy_file_line, $affy_chrom, $affy_pos, $affy_ref, 
                $affy_allele_1, $affy_allele_2) 
                = $self->parse_new_line($affy_file_fh);
        }
        elsif(ncmp($illumina_chrom, $affy_chrom) < 0) {
            ($illumina_file_line, $illumina_chrom, $illumina_pos, 
                $illumina_ref, $illumina_allele_1, $illumina_allele_2) 
                = $self->parse_new_line($illumina_file_fh);
        }
        #same chromosome, compare positions    
        elsif(ncmp($illumina_chrom, $affy_chrom) == 0) {
            if(ncmp($illumina_pos, $affy_pos) > 0) {
                ($affy_file_line, $affy_chrom, $affy_pos, $affy_ref, $affy_allele_1, $affy_allele_2) 
                    = $self->parse_new_line($affy_file_fh);
            }
            elsif(ncmp($illumina_pos, $affy_pos) < 0) {
                ($illumina_file_line, $illumina_chrom, $illumina_pos, $illumina_ref, $illumina_allele_1, $illumina_allele_2) 
                    = $self->parse_new_line($illumina_file_fh);
            }
            # If alleles were not captured (dashes in the file)... get a new line
            elsif (!$illumina_allele_1 || !$illumina_allele_2) { 
                ($illumina_file_line, $illumina_chrom, $illumina_pos, $illumina_ref, $illumina_allele_1, $illumina_allele_2) 
                    = $self->parse_new_line($illumina_file_fh);
            }
            elsif (!$affy_allele_1 || !$affy_allele_2) {
                ($affy_file_line, $affy_chrom, $affy_pos, $affy_ref, $affy_allele_1, $affy_allele_2) 
                    = $self->parse_new_line($affy_file_fh);
            }
            # match position... check alleles
            elsif(ncmp($illumina_pos, $affy_pos) == 0) {
                if (($illumina_allele_1 eq $affy_allele_1) && 
                ($illumina_allele_2 eq $affy_allele_2)) {
                    # Shouldnt matter which one we write to the file
                    # For now, write in an output identical to the current intersection files
                    # FIXME: BIG ASSUMPTIONS:
                    # 1. position start and end are always the same since its just a single position...
                    # 2. Print SNP SNP if homo... print ref SNP if het...
                    # 3. Print this series yet AGAIN for some reason
                    print $output_fh $illumina_chrom . "\t" .
                    $illumina_pos . "\t" .
                    $illumina_pos . "\t" .
                    $illumina_allele_1 . "\t" .
                    $illumina_allele_2 . "\t";
                    # as per the assumption, if it is het print "ref SNP ref SNP"... otherwise SNP SNP SNP SNP
                    if ($illumina_allele_1 eq $illumina_allele_2) {
                        print $output_fh "ref\tSNP\tref\tSNP\n"; 
                    } else {
                        print $output_fh "SNP\tSNP\tSNP\tSNP\n"; 
                    }
                }

                # Now get 2 new lines...
                ($affy_file_line, $affy_chrom, $affy_pos, $affy_ref, 
                $affy_allele_1, $affy_allele_2) 
                = $self->parse_new_line($affy_file_fh);
                
                ($illumina_file_line, $illumina_chrom, $illumina_pos, 
                $illumina_ref, $illumina_allele_1, $illumina_allele_2) 
                = $self->parse_new_line($illumina_file_fh);
            }
        }
    }
    $output_fh->close;

    return 1;
}

# This sub grabs a new line from the parameterized file handle...
# It returns the chromosome, position, ref, allele1, allele2 for that line
# This is intended to work for genotype submission files
sub parse_new_line {
    my ($self, $fh) = @_;

    my $current_file_line = $fh->getline();
    
    if (!$current_file_line) {
        return undef;
    }
    
    # Position will always be the third column
    my @current_tabs = split("\t", $current_file_line);
    my $current_pos = $current_tabs[3];
    # Chromosome is denoted by "C22" "C7" "CY" etc.
    my ($current_chrom) = ($current_file_line =~ m/C(\w+)/);
    # The reference allele and allele 1 will be listed as "A:G" on the line 
    my ($current_ref, $current_allele_1) = ($current_file_line =~ m/([A-Z]):([A-Z])/);
    # Allele 2 will be on the line as "cns=T" if it is a het snp non ref or a homo snp...
    # if it is a het snp matching ref there will be no cns =... so set it equal to ref...
    #FIXME: what happens if allele1 matches ref but allele2 does not? whats the format?
    my ($current_allele_2) = ($current_file_line =~ m/cns=([A-Z])/);
    $current_allele_2 ||= $current_ref;

    return ($current_file_line, $current_chrom, $current_pos, $current_ref, $current_allele_1, $current_allele_2);
}
