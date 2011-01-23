package Genome::Model::Tools::Annotate::CompareMutationsSpeedup;

#__STANDARD PERL PACKAGES
   use warnings;
   use strict;
   use Genome; 
   use FileHandle;
   use Data::Dumper;
   use Storable;
   use Digest::MD5;

#__SPECIAL GENOME CENTER PACKAGES
   ##use GSCApp;
   use MG::Transform::Process::MutationCSV;
   use MG::IO::Parse::Cosmic;

class Genome::Model::Tools::Annotate::CompareMutationsSpeedup{
    is => 'Command',
    has => [
       mutation => {
           is => 'Path',
           doc => 'annotated input file',
       },
       output_file => {
           is => 'Path',
           doc => 'name of the output file containing omim and cosmic mutation comparisons',
       }
    ],
    has_optional=> [
       omimaa_dir => {
           is => 'Path',
           doc => 'omim amino acid mutation database folder',
           default => '/gscmnt/200/medseq/analysis/software/resources/OMIM/OMIM_Will/',
       },
       cosmic_dir => {
           is => 'Path',
           doc => 'cosmic amino acid mutation database folder',
           default => '/gscmnt/sata180/info/medseq/biodb/shared/cosmic/cosmic_will/',
       },
       verbose => {
           is => 'Path',
           doc => 'turn on to display larger working output, default on',
           default => '1',
       },
    ],
};

sub execute{
    my $self = shift;

####################
#  PRE-PROCESSING  #
####################

   my $mut_file = $self->mutation;
   my $cosmic_dir = $self->cosmic_dir;
   my $basename = $self->output_file;
   my $omimaa_dir = $self->omimaa_dir;
   my $omimaa;
   if (-d $omimaa_dir){
   	$omimaa = "$omimaa_dir/omim_aa.csv";
	unless (-e $omimaa) {
	   	$omimaa = "$omimaa_dir/OMIM_aa_will.csv";
	}
   }
   my $cosmic_database_file = 'Cosmic_Database.tsv';
   my $cosmic_database;
   if (-d $cosmic_dir){
	$cosmic_database = "$cosmic_dir/$cosmic_database_file";
   }
   my $verbose = $self->verbose;

   $self->status_message("Using $omimaa as omima db file");
   $self->status_message("Using $cosmic_dir as cosmic db folder");


#####################
#  MAIN PROCESSING  #
#####################
#__SET SOME PARSING PARAMETERS -- UNSURE OF MEANING OF ORIGINAL COMMENTS (MCW)
   my %parse_args = (
#     'check' => 1,

#__PROCESS EVERYTHING INTO A SINGLE STRUCTURE (AND THEN PROCESSED)
		   'all' => 1,

#__HAVE EVERYTHING PROCESSED INTO A SINGLE STRUCTURE (AND NOT PROCESSED)
		   'no_process' => 1,
#process genome tools parser
		   'version' => 'from_genome_tools',
		   );

#Set Stats hash that counts everything
my %stats;
$stats{'OMIMDB'} = 0;
$stats{'OMIM'}{'doublematch'} = 0;
$stats{'OMIM'}{'ntmatch'} = 0;
$stats{'OMIM'}{'aamatch'} = 0;
$stats{'OMIM'}{'posmatch'} = 0;
$stats{'OMIM'}{'ntposmatch'} = 0;
$stats{'OMIM'}{'aaposmatch'} = 0;
$stats{'OMIM'}{'nearmatch'} = 0;
$stats{'OMIM'}{'ntnearmatch'} = 0;
$stats{'OMIM'}{'aanearmatch'} = 0;
$stats{'OMIM'}{'novel'} = 0;
$stats{'OMIM'}{'ntnovel'} = 0;
$stats{'OMIM'}{'aanovel'} = 0;
$stats{'OMIM'}{'silent'} = 0;
$stats{'OMIM'}{'nomatch'} = 0;

$stats{'COSMICDB'} = 0;
$stats{'COSMIC'}{'doublematch'} = 0;
$stats{'COSMIC'}{'ntmatch'} = 0;
$stats{'COSMIC'}{'aamatch'} = 0;
$stats{'COSMIC'}{'posmatch'} = 0;
$stats{'COSMIC'}{'ntposmatch'} = 0;
$stats{'COSMIC'}{'aaposmatch'} = 0;
$stats{'COSMIC'}{'nearmatch'} = 0;
$stats{'COSMIC'}{'ntnearmatch'} = 0;
$stats{'COSMIC'}{'aanearmatch'} = 0;
$stats{'COSMIC'}{'novel'} = 0;
$stats{'COSMIC'}{'ntnovel'} = 0;
$stats{'COSMIC'}{'aanovel'} = 0;
$stats{'COSMIC'}{'silent'} = 0;
$stats{'COSMIC'}{'nomatch'} = 0;

#__NEW MUTATION DATA (.annotated) FILE PARSER OBJECT
my $parser = MG::Transform::Process::MutationCSV->new();
my $fh = new FileHandle;
# open "file.annotated"
unless ($fh->open (qq{$mut_file})) { die "Could not open mutation project file '$mut_file' for reading"; }
my $header = <$fh>;   # place a single line into $line
seek($fh, -length($header), 1); # place the same line back onto the filehandle

if ($verbose) {print "Parsing mutation file...\n";}
$DB::single = 1;
my $mutation = $parser->Parse ($fh, $mut_file, %parse_args);
#  $parser->Write(*STDOUT);
$fh->close;
if ($verbose) {print "Done Parsing Mutation File! Yippee!\n";}

#__READ IN OMIM FILE
   my %omimaa;
   if (defined($omimaa) && -e $omimaa) {
	   open(OMIMAA,$omimaa) || die "Could not open omim file '$omimaa'";
	   if ($verbose) {print "Loading OMIM Database\n";}
	   my $omimaa_header = <OMIMAA>;
	   while(<OMIMAA>) {
		   $stats{'OMIMDB'}++;
		   chomp;
		   my ($gene, $omim_entry, $position, $aa_ori, $aa_mut, $description, $diseases) = split("\t");
		   $omimaa{$gene}{$omim_entry}{$position}{residue1} = $aa_ori;
		   $omimaa{$gene}{$omim_entry}{$position}{residue2} = $aa_mut;
		   $omimaa{$gene}{$omim_entry}{$position}{description} = $description;
	   }
	   if ($verbose) {print "Finished Loading OMIM Database\n";}
	   close(OMIMAA);
   }

#__READ IN COSMIC FILE
   my %cosmic_gene;
   my %cosmic_position;
   my %cosmic_position_only;
   my %cosmic_tissue;
   my %cosmic_histology;
   my %aa_count;
   my %residue_match;
   if (defined($cosmic_database) && -e $cosmic_database) {
	   my ($gene_col, $chr_col, $start_col, $stop_col, $chr_col_37, $start_col_37, $stop_col_37, $amino_col, $nucleo_col, $somatic_col, $primary_tissue_col, $tissue_sub_1_col, $tissue_sub_2_col, $histology_col,
		$histology_sub_1_col, $histology_sub_2_col, $gene, $chr, $start, $stop, $chr_37, $start_37, $stop_37, $amino, $nucleo, $somatic, $primary_tissue, $tissue_sub_1, $tissue_sub_2, $histology, $histology_sub_1,
		$histology_sub_2);
	   open(COSMIC,$cosmic_database) || die "Could not open omim file '$cosmic_database'";
	   if ($verbose) {print "Loading COSMIC Database\n";}
	   my $cosmic_header = <COSMIC>;
	   my @parser = split(/\t/, $cosmic_header);
	   my $parsecount = 0;
	   my %parsehash;
	   foreach my $item (@parser) {
		   $parsehash{$item} = $parsecount;
		   $parsecount++;
	   }
	   $gene_col = $parsehash{'Gene'};
	   $chr_col = $parsehash{'Chromosome'};
	   $start_col = $parsehash{'Genome Start'};
	   $stop_col = $parsehash{'Genome Stop'};
	   $chr_col_37 = $parsehash{'Chromosome Build37'};
	   $start_col_37 = $parsehash{'Genome Start Build37'};
	   $stop_col_37 = $parsehash{'Genome Stop Build37'};
	   $amino_col = $parsehash{'Amino Acid'};
	   $nucleo_col = $parsehash{'Nucleotide'};
	   $somatic_col = $parsehash{'Somatic Status'};
	   $primary_tissue_col = $parsehash{'Primary_Tissue'};
	   $tissue_sub_1_col = $parsehash{'Tissue_subtype_1'};
	   $tissue_sub_2_col = $parsehash{'Tissue_subtype_2'};
	   $histology_col = $parsehash{'Histology'};
	   $histology_sub_1_col = $parsehash{'Histology_subtype_1'};
	   $histology_sub_2_col = $parsehash{'Histology_subtype_2'};

	   while(my $line = <COSMIC>) {
		   $stats{'COSMICDB'}++;
		   chomp($line);
		   my @parser = split(/\t/, $line);
		   $gene = $parser[$gene_col];
		   $chr = $parser[$chr_col];
		   $start = $parser[$start_col];
		   $stop = $parser[$stop_col];
		   $amino = $parser[$amino_col];
		   $nucleo = $parser[$nucleo_col];
		   $somatic = $parser[$somatic_col];
		   $primary_tissue = $parser[$primary_tissue_col];
		   $tissue_sub_1 = $parser[$tissue_sub_1_col];
		   $tissue_sub_2 = $parser[$tissue_sub_2_col];
		   $histology = $parser[$histology_col];
		   $histology_sub_1 = $parser[$histology_sub_1_col];
		   $histology_sub_2 = $parser[$histology_sub_2_col];

           Genome::Model::Tools::Annotate::AminoAcidChange->class(); 
		   my ($residue1, $res_start, $residue2, $res_stop, $new_residue) = @{Genome::Model::Tools::Annotate::AminoAcidChange::check_amino_acid_change_string(amino_acid_change_string =>$amino)};
		   if (defined $res_start){
		   	if ($res_start == $res_stop){
				$residue_match{$gene}{$res_start}{$res_stop}{$residue1}{$residue2}++;
		   		my $addition = $residue1.$res_start.$residue2;
				$aa_count{$gene}{$addition}++;
		  	}
		  	else {
		   		my $addition = $residue1.$res_start."-".$res_stop.$residue2;
				$aa_count{$gene}{$addition}++;
			}
		   }
		   else {
			if ($amino =~ m/\?/ || $amino =~ m/\>/ || $amino eq 'p.V265' || $amino eq 'p.INS' || $amino eq 'p.DEL' || $amino eq 'p.R2468' || $amino eq 'p.fs' ) {
				my $addition = $amino;
				$addition =~ s/p\.//;
				$aa_count{$gene}{$addition}++;
			}
			else {
				print "$residue1, $res_start, $residue2, $res_stop, $new_residue\n";
				die "$amino not found\n";
			}
		   }


		   if (defined($nucleo)) {
			   $cosmic_gene{$gene}{$amino}{$nucleo}++;
		   }
		   else {
			   $cosmic_gene{$gene}{$amino}++;
		   }

		   if (defined($chr) && defined($start) && defined($stop) && $chr ne ' ' && $start ne ' ' && $stop ne ' ') {
			   $cosmic_position{$chr}{$start}{$stop}{$gene}++;
			   if (defined($nucleo)) {
				   $cosmic_position_only{$chr}{$start}{$stop}{$nucleo}++;
			   }
			   else {
				   $cosmic_position_only{$chr}{$start}{$stop}++;
			   }
		   }
		

		   $cosmic_tissue{$gene}{$amino} = "$primary_tissue\t$tissue_sub_1\t$tissue_sub_2";
		   $cosmic_histology{$gene}{$amino} = "$histology\t$histology_sub_1\t$histology_sub_2";
	   }
	   close(COSMIC);
	   if ($verbose) {print "Finished Loading COSMIC Database! Hooray!\n";}
   }

unless ($fh->open (qq{$mut_file})) { die "Could not open mutation project file '$mut_file' for reading"; }
my %fileline;
my $i = 1;
while (my $filehandleline = <$fh>) {
	chomp $filehandleline;
	$fileline{$i} = $filehandleline;
	$i++;
}
$fh->close;

my %cosmic_results;
my %omim_results;
my $summary_file = $basename;
unless (open(SUMMARY,">$summary_file")) {
die "Could not open output file '$summary_file' for writing";
}

print SUMMARY "Line_Number\t$fileline{'1'}\tCosmic_Results\tOMIM_Results\n";
if ($verbose) {print "Starting COSMIC/OMIM to Mutation File Comparisons\n";}
foreach my $hugo (sort keys %{$mutation}) {
foreach my $sample (keys %{$mutation->{$hugo}}) {
foreach my $line_num (keys %{$mutation->{$hugo}->{$sample}}) {
if ($verbose) {print ".";}   #report that we are starting a sample (For commandline user feedback)
#read in the alleles. The keys may change with future file formats. If so, a new version should be added to
#MG::Transform::Process::MutationCSV with a header translation
#            'strand' => 'TUMOR_SAMPLE_ID', # meaningless proxy -- see above
#            'gene_name' => 'HUGO_SYMBOL',


   my ($entrez_gene_id, $line, $aa_change,$transcript,$mstatus,$Variant_Type,$Chromosome,$Start_position,$End_position,$Reference_Allele,$Tumor_Seq_Allele1,$gene) =
	   (
	    $mutation->{$hugo}->{$sample}->{$line_num}->{ENTREZ_GENE_ID},
	    $mutation->{$hugo}->{$sample}->{$line_num}->{file_line},
	    $mutation->{$hugo}->{$sample}->{$line_num}->{AA_CHANGE},
	    $mutation->{$hugo}->{$sample}->{$line_num}->{TRANSCRIPT},
	    $mutation->{$hugo}->{$sample}->{$line_num}->{MUTATION_STATUS},
	    $mutation->{$hugo}->{$sample}->{$line_num}->{VARIANT_TYPE},
	    $mutation->{$hugo}->{$sample}->{$line_num}->{CHROMOSOME},
	    $mutation->{$hugo}->{$sample}->{$line_num}->{START_POSITION},
	    $mutation->{$hugo}->{$sample}->{$line_num}->{END_POSITION},
	    $mutation->{$hugo}->{$sample}->{$line_num}->{REFERENCE_ALLELE},
	    $mutation->{$hugo}->{$sample}->{$line_num}->{TUMOR_SEQ_ALLELE1},
	    $mutation->{$hugo}->{$sample}->{$line_num}->{HUGO_SYMBOL},
	   );
   if ($mstatus){
#Annotate the allele's effect on all known (ie transcript without the 'unknown' status) transcripts
#                my ($temp_input, $filename) = Genome::Sys->create_temp_file;
##Alleles are listed in alphabetical order, find the one that actually is different               
	my $proper_allele = $Tumor_Seq_Allele1;
# MCW NOTE: '0' IS AN INDEL AND THIS IS VALID
#LOOK FOR ONLY SINGLE CHARACTER PROPER ALLELE TYPES - A, C, T, G, 0, or -
	unless($Reference_Allele ne $proper_allele) {
		die "Ref allele: $Reference_Allele same as mutation allele: $proper_allele ('line num' $line_num)";
	}
	unless($Reference_Allele =~ /[ACTG0\-]/ && $proper_allele =~ /[ACTG0\-]/) {
		die "Read in improper alleles from mutation file ref: $Reference_Allele var: $proper_allele ('line num' $line_num)";
	}

## MCW PROVISIONAL: DAVE LARSON SAID THERE SHOULD NEVER BE '--' BECAUSE THE CODE
##  WILL THINK THIS IS A DINUCLEOTIDE POLYMORPHISM INSTEAD OF AN INDEL, SO CHANGE THESE
	$Reference_Allele = '-' if $Reference_Allele eq '--';
	$proper_allele = '-' if $proper_allele eq '--';
	chomp($line_num);
	my %results_hash;
#parse the amino acid string
    Genome::Model::Tools::Annotate::AminoAcidChange->class();
	my ($residue1, $res_start, $residue2, $res_stop, $new_residue) =@{Genome::Model::Tools::Annotate::AminoAcidChange::check_amino_acid_change_string(amino_acid_change_string => $aa_change)};
	if(!$residue2 || $residue2 eq ' '){
		if ($verbose) {print "Skipping Silent Mutation";}
		my $createspreadsheet = "$line_num\t$fileline{$line_num}\tSkipped - Silent Mutation\tSkipped - Silent Mutation";
		print SUMMARY "$createspreadsheet\n";
		$stats{'COSMIC'}{'silent'}++;
		$stats{'OMIM'}{'silent'}++;
		next; #skip silent mutations
	}

	#look for mutation file gene ($hugo) to match cosmic file gene (%cosmic_gene{gene}), note matched name in $cosmic_hugo
	my $cosmic_hugo;
	my $uc_hugo = uc($hugo);
	if (exists($cosmic_gene{$hugo})) {
		$cosmic_hugo = $hugo;
	}
	elsif (exists($cosmic_gene{$uc_hugo})) {	   # check for UPPERCASE hugo match
		$cosmic_hugo = $uc_hugo;
	}
	else {
		#if cosmic key needs to be uppercase to match mutation file (for example, maf default is all uppercase)
		foreach my $key (keys %cosmic_gene) {	   # check for UPPERCASE keys match
			if ($uc_hugo eq uc($key)) {
				$cosmic_hugo = $key;
			}
		}
	}

	#genes that didn't find a match go here, will check for position matches later
	unless (defined($cosmic_hugo)) {
   		if (-e "$cosmic_dir/$hugo\.csv") { #database flatfile has only genes with AA changes, check source files for gene existance
			$results_hash{NT}{NOVEL}{COSMIC}{$transcript}=": Gene $hugo in Cosmic but No Amino Acid Results for Gene";
		} 
		else {
			$results_hash{NT}{NOVEL}{COSMIC}{$transcript}=": Gene $hugo not in Cosmic Database";
		}
	}

#retrieve COSMIC match
	if (!defined($aa_change) || $aa_change eq 'NULL') {
		warn "We skipped silent mutations, how do we have undel or NULL amino acids at non-silent sites? Gene:$hugo AA:$aa_change\n";
	}

	#Start checks,First check position (then check amino acid)
	my $find_type;
        my $cosmic_find_type;
        my @aa_holder;
	if(defined($Start_position) && defined($End_position) && $Start_position ne ' ' && $End_position ne ' ') {
		my $genomic_start = $Start_position;
		my $genomic_stop = $End_position;
		my $nt1 = $Reference_Allele;
		my $nt2 = $proper_allele;
		$find_type = 'no_match';
		foreach my $chr (sort keys %cosmic_position_only) {
			# Test that it at least matches position
####LOOPS NOT NEEDED NOW THAT IT'S HASH STRUCTURE
			foreach my $gen_start (keys %{$cosmic_position_only{$chr}}) {
				my $diff_start = $gen_start - $genomic_start;
				if ($gen_start == $genomic_start) {
					foreach my $gen_stop (keys %{$cosmic_position_only{$chr}{$gen_start}}) {
						my $diff_stop = $gen_stop - $genomic_stop;
						if ($gen_stop == $genomic_stop) {
							$find_type = 'position';
							my $cosmic_genes;
							if (keys %{$cosmic_position{$chr}{$gen_start}{$gen_stop}}) {
								my @cosmic_genes = keys %{$cosmic_position{$chr}{$gen_start}{$gen_stop}};
								$cosmic_genes = join(",",@cosmic_genes);
							}
							$results_hash{NT}{POSITION}{COSMIC}{$transcript}=": Nucleotide -> Cosmic Gene(s):$cosmic_genes Position:$chr:$gen_start-$gen_stop";
							# Test that it matches both
							foreach my $nucleo (keys %{$cosmic_position_only{$chr}{$gen_start}{$gen_stop}}) {
								my ($start,$stop,$type_length,$type,$reference,$mutant) = parse_nucleotide($nucleo,$verbose);
								if($reference && $mutant && $reference eq $nt1 && $mutant eq $nt2) {
									$find_type = 'position_nucleotide';
									$results_hash{NT}{MATCH}{COSMIC}{$transcript} = ": Nucleotide -> Cosmic Gene(s): $cosmic_genes Position:$chr:$gen_start-$gen_stop,ref:$reference,mut:$mutant";
								}
							}
						}
						elsif ($diff_stop <= 5 && $diff_stop >= -5) {
							$results_hash{NT}{ALMOST}{COSMIC}{$transcript}=": Nucleotide";
						}
					}
				}
				elsif ($diff_start <= 5 && $diff_start >= -5) {
					$results_hash{NT}{ALMOST}{COSMIC}{$transcript}=": Nucleotide";
				}
			}
		}
	   	if($find_type && $find_type eq 'no_match') {
			$results_hash{NT}{NOVEL}{COSMIC}{$transcript}=": Nucleotide";
	   	}
	}

	#check amino acid here
        if ($cosmic_hugo && exists($cosmic_gene{$cosmic_hugo})) {
		$cosmic_find_type = 'no_match';
		foreach my $key (keys %{$aa_count{$cosmic_hugo}}) {
			if ($key =~ m/\S+/) {
		   		push(@aa_holder,"$key ($aa_count{$cosmic_hugo}{$key})");
			}
		}
		unless (@aa_holder) {
			@aa_holder = "AA?Unknown?";
		}
		if ($res_start && $res_stop && exists($residue_match{$cosmic_hugo}) && exists($residue_match{$cosmic_hugo}{$res_start}) && exists($residue_match{$cosmic_hugo}{$res_start}{$res_stop})) { #match amino acid
			$cosmic_find_type = 'position';
			$results_hash{AA}{POSITION}{COSMIC}{$transcript}=": Amino Acid -> Matched $cosmic_hugo, $res_start, $res_stop";
			if ($residue1 && $residue2 && ($residue_match{$cosmic_hugo}{$res_start}{$res_stop}{$residue1}{$residue2} || $residue_match{$cosmic_hugo}{$res_start}{$res_stop}{uc($residue1)}{$residue2} || $residue_match{$cosmic_hugo}{$res_start}{$res_stop}{$residue1}{uc($residue2)} || $residue_match{$cosmic_hugo}{$res_start}{$res_stop}{uc($residue1)}{uc($residue2)})) { # matches both amino acid and amino acid position
				$cosmic_find_type = 'position_aminoacid';
				my $addition;
		   		if ($res_start == $res_stop){
					$addition = $residue1.$res_start.$residue2;
				}
			  	else {
			   		$addition = $residue1.$res_start."-".$res_stop.$residue2;
				}
				$results_hash{AA}{MATCH}{COSMIC}{$transcript} = ": Amino Acid -> Matched $cosmic_hugo, $addition";
			}
		}
		if($cosmic_find_type && $cosmic_find_type eq 'no_match') {
			$results_hash{AA}{NOVEL}{COSMIC}{$transcript}=": Amino Acid -> Known AA = @aa_holder";
			my $iter_start = $res_start - 2;
			my $iter_stop = $res_stop + 2;
			my $iter;
			for($iter = $iter_start; $iter <= $iter_stop; $iter++) {
				if ($res_start && $res_stop && exists($residue_match{$cosmic_hugo}) && exists($residue_match{$cosmic_hugo}{$iter})) {
					$results_hash{AA}{ALMOST}{COSMIC}{$transcript} = ": Amino Acid -> Known AA for Gene = @aa_holder";
				}
			}
		}
        }

	#retrieve OMIM match
	my $omim_find_type;
	my $omim = \%omimaa;
	if (exists($omim->{$hugo})) {
		$omim_find_type = FindOMIM(\%omimaa,$hugo,$res_start,$res_stop,$residue1,$residue2);
	}
	#Add OMIM result to the results hash
	if(defined($omim_find_type)) {
		if ($omim_find_type eq 'position_aminoacid') {
			$results_hash{AA}{MATCH}{OMIM}{$transcript} =": Amino Acid";
		} 
		elsif ($omim_find_type eq 'position') {
			$results_hash{AA}{POSITION}{OMIM}->{$transcript}=": Amino Acid";
		} 
		elsif ($omim_find_type eq 'almost') {
			$results_hash{AA}{ALMOST}{OMIM}->{$transcript}=": Amino Acid";
		} 
		else {
			$results_hash{AA}{NOVEL}{OMIM}->{$transcript}=": Amino Acid";
		}
	} 
	else {
		$results_hash{AA}{NOVEL}{OMIM}->{$transcript}=": Amino Acid - OMIM Gene Name Not Found";
	}

	#now check to see what the 'best' cosmic score was
	my $matchtype_cosmic;
	($cosmic_results{$line_num}, $matchtype_cosmic) = score_results(\%results_hash, "COSMIC");
	$stats{'COSMIC'}{$matchtype_cosmic}++;
	#now check to see what the 'best' omim score was
	my $matchtype_omim;
	($omim_results{$line_num}, $matchtype_omim) = score_results(\%results_hash, "OMIM");
	$stats{'OMIM'}{$matchtype_omim}++;

	my $createspreadsheet = "$line_num\t$fileline{$line_num}\t$cosmic_results{$line_num}\t$omim_results{$line_num}";
	print SUMMARY "$createspreadsheet\n";
   }
}
}
}
close(SUMMARY);
if ($verbose) {print "Finished COSMIC/OMIM to Mutation File Comparisons! HAPPY HAPPY JOY JOY!\n";}

print "\n";
print "Number of Genes in OMIM: $stats{'OMIMDB'}\n";
print "Number of AA and NT Matches: $stats{'OMIM'}{'doublematch'}\n";
print "Number of NT only Matches: $stats{'OMIM'}{'ntmatch'}\n";
print "Number of AA only Matches: $stats{'OMIM'}{'aamatch'}\n";
print "Number of AA and NT Position Matches: $stats{'OMIM'}{'posmatch'}\n";
print "Number of NT only Position Matches: $stats{'OMIM'}{'ntposmatch'}\n";
print "Number of AA only Position Matches: $stats{'OMIM'}{'aaposmatch'}\n";
print "Number of NT and AA Novel Sites with Matches in Near Proximity: $stats{'OMIM'}{'nearmatch'}\n";
print "Number of NT only Novel Sites with Matches in Near Proximity: $stats{'OMIM'}{'ntnearmatch'}\n";
print "Number of AA only Novel Sites with Matches in Near Proximity: $stats{'OMIM'}{'aanearmatch'}\n";
print "Number of NT and AA Novel Sites with Nothing in Near Proximity: $stats{'OMIM'}{'novel'}\n";
print "Number of NT Novel Sites with Nothing in Near Proximity: $stats{'OMIM'}{'ntnovel'}\n";
print "Number of AA Novel Sites with Nothing in Near Proximity: $stats{'OMIM'}{'aanovel'}\n";
print "Number of Silent Mutations Skipped: $stats{'OMIM'}{'silent'}\n";
print "Number of Lines that Exited with No Hit: $stats{'OMIM'}{'nomatch'}\n";
print "\n";
print "Number of Genes in COSMIC: $stats{'COSMICDB'}\n";
print "Number of AA and NT Matches: $stats{'COSMIC'}{'doublematch'}\n";
print "Number of NT only Matches: $stats{'COSMIC'}{'ntmatch'}\n";
print "Number of AA only Matches: $stats{'COSMIC'}{'aamatch'}\n";
print "Number of AA and NT Position Matches: $stats{'COSMIC'}{'posmatch'}\n";
print "Number of NT only Position Matches: $stats{'COSMIC'}{'ntposmatch'}\n";
print "Number of AA only Position Matches: $stats{'COSMIC'}{'aaposmatch'}\n";
print "Number of NT and AA Novel Sites with Matches in Near Proximity: $stats{'COSMIC'}{'nearmatch'}\n";
print "Number of NT only Novel Sites with Matches in Near Proximity: $stats{'COSMIC'}{'ntnearmatch'}\n";
print "Number of AA only Novel Sites with Matches in Near Proximity: $stats{'COSMIC'}{'aanearmatch'}\n";
print "Number of NT and AA Novel Sites with Nothing in Near Proximity: $stats{'COSMIC'}{'novel'}\n";
print "Number of NT Novel Sites with Nothing in Near Proximity: $stats{'COSMIC'}{'ntnovel'}\n";
print "Number of AA Novel Sites with Nothing in Near Proximity: $stats{'COSMIC'}{'aanovel'}\n";
print "Number of Silent Mutations Skipped: $stats{'COSMIC'}{'silent'}\n";
print "Number of Lines that Exited with No Hit: $stats{'COSMIC'}{'nomatch'}\n";

return 1;
}




################################################################################
#                                                                              #
#                            S U B R O U T I N E S                             #
#                                                                              #
################################################################################




sub FindOMIM {
	my ($omim, $hugo,$res_start, $res_stop, $residue1, $residue2) = @_;

	my $return_value = 'no_match';
	unless (exists($omim->{$hugo})) {
		warn "No omim entry for: $hugo";
		return $return_value;
	}
	foreach my $sample (keys %{$omim->{$hugo}}) {
		# Test that it at least matches position
		if (exists($omim->{$hugo}{$sample}{$res_start})) {
			$return_value = 'position';
			# Test that it matches both
			if (exists($omim->{$hugo}{$sample}{$res_start}{residue1}) &&
					exists($omim->{$hugo}{$sample}{$res_start}{residue2}) &&
					defined($omim->{$hugo}{$sample}{$res_start}{residue1}) &&
					defined($omim->{$hugo}{$sample}{$res_start}{residue2}) &&
					uc($omim->{$hugo}{$sample}{$res_start}{residue1}) eq uc($residue1) &&
					uc($omim->{$hugo}{$sample}{$res_start}{residue2}) eq uc($residue2)) {
				return 'position_aminoacid';
			}
		}
		elsif ($return_value eq 'no_match') {
			my $iter_start = $res_start - 2;
			my $iter_stop = $res_stop + 2;
			my $iter;
			for($iter = $iter_start; $iter <= $iter_stop; $iter++) {
				if (exists($omim->{$hugo}{$sample}{$iter})) {
					$return_value = 'almost';
				}
			}
		}
	}
	return $return_value;
}

sub score_results {
	my ($results, $database) = @_;
	my $matchtype;
	if(exists($results->{NT}{MATCH}->{$database}) && exists($results->{AA}{MATCH}->{$database})) {
#best hit was a DOUBLE MATCH. Huzzah!
		$matchtype = 'doublematch';
		my ($transcript) = keys %{$results->{NT}{MATCH}{$database}};
		my ($transcript2) = keys %{$results->{AA}{MATCH}{$database}};
		my $ret_value = "NT and AA Match".$results->{AA}{MATCH}->{$database}{$transcript2}." and ".$results->{NT}{MATCH}->{$database}{$transcript};
		return ($ret_value, $matchtype);
	}
	elsif(exists($results->{NT}{MATCH}->{$database})) {
#best hit was a MATCH. Huzzah!
		$matchtype = 'ntmatch';
		my ($transcript) = keys %{$results->{NT}{MATCH}{$database}};
		my $ret_value = "Match".$results->{NT}{MATCH}->{$database}{$transcript};
		return ($ret_value, $matchtype);
	}
	elsif(exists($results->{AA}{MATCH}->{$database})) {
#best hit was a MATCH. Huzzah!
		$matchtype = 'aamatch';
		my ($transcript) = keys %{$results->{AA}{MATCH}{$database}};
		my $ret_value = "Match".$results->{AA}{MATCH}->{$database}{$transcript};
		return ($ret_value, $matchtype);
	}
	elsif(exists($results->{NT}{POSITION}->{$database}) && exists($results->{AA}{POSITION}->{$database})) {
#best hit was a position match
		$matchtype = 'posmatch';
		my ($transcript) = keys %{$results->{NT}{POSITION}{$database}};
		my ($transcript2) = keys %{$results->{AA}{POSITION}{$database}};
		my $ret_value = "NT and AA Near Match (Position)".$results->{AA}{POSITION}->{$database}{$transcript2}." and ".$results->{NT}{POSITION}->{$database}{$transcript};
		return ($ret_value, $matchtype);
	}
	elsif(exists($results->{NT}{POSITION}->{$database})) {
#best hit was a position match
		$matchtype = 'ntposmatch';
		my ($transcript) = keys %{$results->{NT}{POSITION}{$database}};
		my $ret_value = "Near Match (Position)".$results->{NT}{POSITION}->{$database}{$transcript};
		return ($ret_value, $matchtype);
	}
	elsif(exists($results->{AA}{POSITION}->{$database})) {
#best hit was a position match
		$matchtype = 'aaposmatch';
		my ($transcript) = keys %{$results->{AA}{POSITION}{$database}};
		my $ret_value = "Near Match (Position)".$results->{AA}{POSITION}->{$database}{$transcript};
		return ($ret_value, $matchtype);
	}
	elsif(exists($results->{NT}{ALMOST}->{$database}) && exists($results->{AA}{ALMOST}->{$database})) {
#best hit was near a position match
		$matchtype = 'nearmatch';
		my ($transcript) = keys %{$results->{NT}{ALMOST}{$database}};
		my ($transcript2) = keys %{$results->{AA}{ALMOST}{$database}};
		my $ret_value = "NT and AA Novel, but near match".$results->{AA}{ALMOST}->{$database}{$transcript2}." and ".$results->{NT}{ALMOST}->{$database}{$transcript};
		return ($ret_value, $matchtype);
	}
	elsif(exists($results->{NT}{ALMOST}->{$database})) {
#best hit was near a position match
		$matchtype = 'ntnearmatch';
		my ($transcript) = keys %{$results->{NT}{ALMOST}{$database}};
		my $ret_value = "Novel, but near match".$results->{NT}{ALMOST}->{$database}{$transcript};
		return ($ret_value, $matchtype);
	}
	elsif(exists($results->{AA}{ALMOST}->{$database})) {
#best hit was near a position match
		$matchtype = 'aanearmatch';
		my ($transcript) = keys %{$results->{AA}{ALMOST}{$database}};
		my $ret_value = "Novel, but near match".$results->{AA}{ALMOST}->{$database}{$transcript};
		return ($ret_value, $matchtype);
	}
	elsif(exists($results->{AA}{NOVEL}->{$database}) && exists($results->{NT}{NOVEL}->{$database})) {
#no hits, novel
		$matchtype = 'novel';
		my ($transcript) = keys %{$results->{AA}{NOVEL}{$database}};
		my ($transcript2) = keys %{$results->{NT}{NOVEL}{$database}};
		my $ret_value = "Novel".$results->{AA}{NOVEL}->{$database}{$transcript}. " and ".$results->{NT}{NOVEL}->{$database}{$transcript2};
		return ($ret_value, $matchtype);
	}
	elsif(exists($results->{AA}{NOVEL}->{$database})) {
#no hits, novel
		$matchtype = 'aanovel';
		my ($transcript) = keys %{$results->{AA}{NOVEL}{$database}};
		my $ret_value = "Novel".$results->{AA}{NOVEL}->{$database}{$transcript};
		return ($ret_value, $matchtype);
	}
	elsif(exists($results->{NT}{NOVEL}->{$database})) {
#no hits, novel
		$matchtype = 'ntnovel';
		my ($transcript) = keys %{$results->{NT}{NOVEL}{$database}};
		my $ret_value = "Novel".$results->{NT}{NOVEL}->{$database}{$transcript};
		return ($ret_value, $matchtype);
	}
	else {
#it was a nomatch! this shouldn't happen.
		$matchtype = 'nomatch';
		my ($transcript) = keys %{$results->{NOMATCH}};
		my $ret_value = (defined($transcript) && $results->{NOMATCH}{$transcript}) ?  $results->{NOMATCH}{$transcript} : "Unknown/NULL";
		return ($ret_value, $matchtype);
	}
}

sub parse_nucleotide {
	my ($string, $verbose) = @_;
#should start as c.nt_nttype
#don't care so much about the nt numbers as much as the associated data
	my ($change, $modifier);
	my ($start,$stop,$type_length,$type,$reference,$mutant);
	($start,$stop,$change) = $string =~ /^c\. (\d+) _ (\d+) (.*) $/x;
	unless (defined $change) {
		($start,$change) = $string =~ /^c\. (\d+) (.*) $/x;
	}
	if ($string =~ /^c\.\w* \Q?\E.* /x) {
#ambiguous entry
		return;
	}
	if( defined $change) {
#first check to make sure its not intronic
		if ($change =~ /^ (-|\+) (\d+) (.*) $/x) {
			if ($verbose) {print "Mutation Appears Intronic";}
			$change = $3;
		}
#This could be one of several possiblities
#First distinguish between > notation and del18 notation
		($reference,$mutant) = $change =~ /^ (\D*) > (\D+) $/x;
		if(defined($reference) && $reference eq '') {
			$reference = undef;
		}
		if(defined $mutant) {
#Then we expect that this format is correct.
#Testing $mutant because c.2245_2269>G exists in COSMIC
			if((defined($stop) &&  $stop eq $start) || !defined($stop))  {
#We have a snp
				$type = 'SNP';
				$type_length = 1;
			}
			else {
#assuming that if it is listed explicitly it is an indel
				$type = 'indel';
				if(defined $reference) {
					$type_length = length $reference;
				} 
				else {
					$type_length = abs($start-$stop)+1;
				}
			}
			return ($start, $stop, $type_length, $type, $reference, $mutant);       
		}
		else {
#did not guess right. Should be either del15 or insAAT type of
#format
			$type = substr $change, 0,3;
			$modifier = substr $change, 3, (length($change) - 1);
			if($type =~ /^ (del|ins|delins) $/xi) {
				if($type eq 'delins') {
					$type = 'indel';
				}
#then insertion
				if($modifier =~ /^ (\d+) $/x) {
#it is a digit
					$type_length = $1;
					return ($start, $stop, $type_length, $type, $reference, $mutant);
				}
				else {

#it is a sequence
					$type_length = length $modifier;
					return ($start, $stop, $type_length, $type, $reference, $modifier);
				}
			}
			else {
#unrecognized format
				warn "Unable to parse nucleotide format in: $string\n";
				return;
			}
		}
	}
	else {
		warn "Unable to parse nucleotide format in: $string\n";
		return;
	}
}


################################################################################
#                                                                              #
#                      P O D   D O C U M E N T A T I O N                       #
#                                                                              #
################################################################################

=head1 NAME

gt_annotated_mutation_versus_known -- compares the amino acid changes in a .annotated file to the entries (if present) in the COSMIC and OMIM files

=head1 SYNOPSIS

gmt annotate compare-mutations --mutation=/gscuser/wschierd/code/test_annotated/Test/06-02-2010_cosmic_omim_test.csv --omimaa=/gscmnt/200/medseq/analysis/software/resources/OMIM/OMIM_Will/OMIM_aa_will.csv --cosmic-dir=/gscmnt/sata180/info/medseq/biodb/shared/cosmic/cosmic_will/ --output-file=/gscuser/wschierd/code/test_annotated/Test/cosmic_OMIM_test_results_compare.csv 

gmt annotate compare-mutations-speedup --mutation=/gscuser/wschierd/code/test_annotated/Test/06-02-2010_cosmic_omim_test.csv --omimaa=/gscmnt/200/medseq/analysis/software/resources/OMIM/OMIM_Will/OMIM_aa_will.csv --cosmic-dir=/gscmnt/sata180/info/medseq/biodb/shared/cosmic/cosmic_will/ --output-file=/gscuser/wschierd/code/test_annotated/Test/cosmic_OMIM_test_results_compare_speedup.csv 

=head1 DESCRIPTION

This script takes a gmt .annotated file, the directory where COSMIC files are stored, the file containing amino acids in OMIM, and a basename. It compares all possible annotations for every mutation in the file and outputs the results into a 2-column results file called basename_results.csv.

As of September 2009, the headers in this file were up-to-date. This file will have to be modified any time these header names change as well as updating the parser.

In order to speed up this program, I added support for a cosmic archive file. This file is generated in the COSMIC directory. It is regenerated automatically if any of the individual COSMIC files are newer than it. In addition, I am archiving an MD5 checksum to the parser source used to generate the archive. If the checksum changes then the archive is regenerated and the new checksum stored. If this script is ever run frequently this could prove to be problematic and should probably be re-written using file-locks.

If you are concerned about this feature. Just run the program with the -rearchive option.

Remember to look in the log file for any problems such as the following:

2007/09/24 11:42:40	linus215(643)	bshore	WARN	main::FindCosmicmutation_versus_cosmic.pl:158	Null values for gene: RANBP9 sample: 17194 line_number: 760
10048,"RANBP9","ENST00000011619",6,13730573,13730573,-1,"Missense","SNP","C","p.730Y","G","C",0,0,17194,"C","C","G","C","C","C",1,"S"


=head2 EXPORT

None by default.

=head1 SEE ALSO

MG::Transform::Process::MutationCSV for code on parsing the file

MG::IO::Parse::Cosmic for code on reading cosmic files

=head1 FILES

=head1 BUGS

I'm sure that you'll find some. Let us know. Ants.

=head1 AUTHORS

Brian Dunford-Shore, E<lt>bshore@watson.wustl.eduE<gt>

David Larson, E<lt>dlarson@watson.wustl.eduE<gt>

Michael C. Wendl, E<lt>mwendl@wustl.eduE<gt>

William Schierding, E<lt>wschierd@genome.wustl.eduE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007-2009 Washington University.  All Rights Reserved.

=cut

# $Header$
