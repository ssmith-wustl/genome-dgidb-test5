package Genome::Model::Tools::Annotate::CompareMutations;

use strict;
use warnings;

use Genome; 

#__STANDARD PERL PACKAGES
   use warnings;
   use strict;
   use FileHandle;
   use Data::Dumper;
   use Storable;
   use Digest::MD5;

#__SPECIAL GENOME CENTER PACKAGES
   ##use GSCApp;
   use MG::Transform::Process::MutationCSV;
   use MG::IO::Parse::Cosmic;

class Genome::Model::Tools::Annotate::CompareMutations{
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
       omimaa => {
           is => 'Path',
           doc => 'omim amino acid mutation database',
           default => '/gscmnt/200/medseq/analysis/software/resources/OMIM/OMIM_Will/',
       },
       cosmic_dir => {
           is => 'Path',
           doc => 'cosmic amino acid mutation database',
           default => '/gscmnt/sata180/info/medseq/biodb/shared/cosmic/cosmic_will/',
       },
       force_rearchive => {
           is => 'Boolean',
           doc => "rearchives cosmic cache, defaults to don't force rearchive",
           default => 0,
       }
    ],
};

sub execute{
    my $self = shift;

####################
#  PRE-PROCESSING  #
####################

#__LOGGING OBJECTS
   my ($logmp, $logger);

   my $mut_file = $self->mutation;
   my $cosmic_dir = $self->cosmic_dir;
   my $basename = $self->output_file;
   my $mutversion = 'from_genome_tools';
   my $egi_filter; #not handling exclusion files currently
   my $omimaa = $self->omimaa;
   if (-d $omimaa){
   	$omimaa .= '/omim_aa.csv';
   }
   my $force_rearchive = $self->force_rearchive;

    $self->status_message("Using $omimaa as omima db file");
    $self->status_message("Using $cosmic_dir as cosmic db folder");

#__PRINT USAGE IF NEEDED --- NOTE THERE'S NOT MUCH GOOD INFO THAT PRINTS
#  AT THE MOMENT (MCW)
   unless (defined $basename && defined $mut_file && defined $cosmic_dir && defined $omimaa) {
	   App::Getopt->usage && exit(1);
   }

#####################
#  MAIN PROCESSING  #
#####################

#__CONNECT TO PROpDUCTION DATABASE
   MPSampleData::DBI::myinit ("dbi:Oracle:dwrac","mguser_prd");

#__READ IN EXCLUSION TAGS IF AN EXCLUSION FILE IS SPECIFIED
   my %egi_exclude;
   if (defined($egi_filter) && -e $egi_filter) {
	   open (EGI,$egi_filter) || die "Could not open filter file '$egi_filter'";
	   while (<EGI>) {
		   chomp;
		   $egi_exclude{$_} = 1;
	   }
	   close(EGI);
   }

#__READ IN OMIM FILE
   my %omimaa;
   if (defined($omimaa) && -e $omimaa) {
	   open(OMIMAA,$omimaa) || die "Could not open omim file '$omimaa'";
	   print "Reading OMIM\n";
	   my $omimaa_header = <OMIMAA>;
	   while(<OMIMAA>) {
		   chomp;
		   my ($gene, $omim_entry, $position, $aa_ori, $aa_mut, $description) = split("\t");
		   $omimaa{$gene}{$omim_entry}{$position}{residue1} = $aa_ori;
		   $omimaa{$gene}{$omim_entry}{$position}{residue2} = $aa_mut;
		   $omimaa{$gene}{$omim_entry}{$position}{description} = $description;
	   }
	   close(OMIMAA);
   }

#__SET SOME PARSING PARAMETERS -- UNSURE OF MEANING OF ORIGINAL COMMENTS (MCW)
   my %parse_args = (
#     'check' => 1,

#__PROCESS EVERYTHING INTO A SINGLE STRUCTURE (AND THEN PROCESSED)
		   'all' => 1,

#__HAVE EVERYTHING PROCESSED INTO A SINGLE STRUCTURE (AND NOT PROCESSED)
		   'no_process' => 1,
		   );

#__CREATE NEW PARSER OBJECT AND SET-UP CHECKSUM FOR COSMIC CACHE
   print "doing checksum operations\n";
   my $cosmic_parser = MG::IO::Parse::Cosmic->new(
		   'source' => 'cosmic', 'skip_geneid' => 1,
		   );
   my $cosmic_parser_path = $INC{"MG/IO/Parse/Cosmic.pm"};
   print "Using cosmic parser at path: $cosmic_parser_path\n";
   my $source_handle = new FileHandle;
   $source_handle->open ($cosmic_parser_path,"r") ||
	   die "Couldn't read the source code for the parser";
   my $md5 = Digest::MD5->new;
   $md5->addfile ($source_handle);
   my $checksum = $md5->digest();
   $source_handle->close;

#__GET LIST OF ALL COSMIC GENE FILES
   my @cosmic_files = glob ($cosmic_dir . '/*.csv');
###opendir (DIR, $cosmic_dir) || die "cant access '$cosmic_dir'";
###my @cosmic_files = grep /\S+\.csv/, readdir (DIR);
###closedir (DIR);
#  my $ldkjljkd = scalar @cosmic_files;
#  print "CHECKPOINT number = $ldkjljkd\n";
die "no cosmic files found in '$cosmic_dir'" unless scalar @cosmic_files;

#__EITHER GET THE COSMIC CACHED INFO USING CHECKSUM ID SYSTEM
my $cosmic;
my $cosmic_archive_file = "$cosmic_dir/.cosmic_archive";
if (-e $cosmic_archive_file && !$force_rearchive) {
#     print "DEBUG: cosmic archive detected -- will try to load from here\n";

#__AGE (IN DAYS) OF LAST COSMIC ARCHIVE
my $archive_age = -M $cosmic_archive_file;
#     print "DEBUG: cosmic archive age is $archive_age days\n";

#__CHECK ARCHIVE CACHE AGAINST ALL COSMIC GENE FILES IN COSMIC DIRECTORY
#     my @cosmic_files = glob ($cosmic_dir . '/*.csv');
foreach my $cosmic_file (@cosmic_files) {

#__IF COSMIC FILE FOR THIS GENE IS NEWER THAN ARCHIVE THEN UPDATE THE
#  ENTIRE ARCHIVE AND, INCIDENTALLY, LOAD ALL THE INFORMATION
if (-M $cosmic_file < $archive_age) {
print "Cosmic archive is out of date w.r.t. gene $cosmic_file\n";
$cosmic = &load_and_checksum_cosmic_files ($cosmic_archive_file,
$cosmic_dir, $checksum, $cosmic_parser, @cosmic_files);
last;
}
}
#     print "DEBUG: nothing out of date - so did not load yet\n";

#__LOAD COSMIC INFORMATION IF IT HAS NOT BEEN LOADED YET
unless ($cosmic) {

#__FIRST CHECK PARSER STATUS IF THERE'S A PARSER CHECKSUM
if (-e "$cosmic_dir/.parser_md5_checksum") {
#           print "DEBUG: checksum detected -- will try to load from here\n";

#__RETRIEVE PARSER'S CHECKSUM
my $checksum_file = new FileHandle;
$checksum_file->open ("$cosmic_dir/.parser_md5_checksum","r") ||
die "Couldn't read checksum file\n";
my $dir_checksum = <$checksum_file>;
chomp $dir_checksum;
$checksum_file->close();

#__IF CHECKSUM IS OK THEN SIMPLY RETRIEVE THE CACHED PARSE
if ($checksum eq $dir_checksum) {
#              print "DEBUG: checksum confirms -- now loading\n";
$cosmic = Storable::retrieve ($cosmic_archive_file);

#__ELSE DO A FULL PARSE AND THEN ARCHIVE (CACHE) IT
} else {
#              print "DEBUG: dir checksum '$dir_checksum' diff from local checksum '$checksum'\n";
print "Cosmic parser has changed since last archive\n";
$cosmic = &load_and_checksum_cosmic_files ($cosmic_archive_file,
$cosmic_dir, $checksum, $cosmic_parser, @cosmic_files);
}

#__ELSE DO A FULL PARSE AND THEN ARCHIVE (CACHE) IT
} else {
print "No MD5 checksum found. Re-archiving!\n";
$cosmic = &load_and_checksum_cosmic_files ($cosmic_archive_file,
$cosmic_dir, $checksum, $cosmic_parser, @cosmic_files);
}
}

#__ELSE DO A FULL PARSE AND THEN ARCHIVE (CACHE) IT
} else {
print "Cosmic archive not found\n";
#     my @cosmic_files = glob ($cosmic_dir . '/*.csv');
$cosmic = &load_and_checksum_cosmic_files ($cosmic_archive_file,
$cosmic_dir, $checksum, $cosmic_parser, @cosmic_files);
}

#__CHECK MATTERS ONE LAST TIME BEFORE PROCEEDING
if ($cosmic) {

#__CHECK PARSER ONE LAST TIME
unless ($cosmic->{PARSER_CHECKSUM} eq $checksum) {
die "Mismatch between $cosmic archive and parser. Delete the .parser_md5_checksum and try again\n"
}
delete $cosmic->{PARSER_CHECKSUM};
} else {
die "Unable to load Cosmic data\n";
}

########### DEBUG
# print "DEBUG: NOW POSTING DATA FOR TP53 MUTATION p.H193R\n";
# &PostData ($cosmic->{'TP53'}->{'906851|10742| '});
# &PostData ($cosmic->{'TP53'}->{'909721|10742| '});
# &PostData ($cosmic->{'TP53'}->{'753573|10742| '});
# &PostData ($cosmic->{'TP53'}->{'910853|10742| '});
########### DEBUG

# chromosome_name start stop reference variant type gene_name transcript_name transcript_species
# transcript_source trnascript_version strand transcript_status trv_type c_position
# amino_acid_change ucsc_cons domain all_domains

# now must handle *.annotated files

#__NEW MUTATION DATA (.annotated) FILE PARSER OBJECT
my $parser = MG::Transform::Process::MutationCSV->new();
my $fh = new FileHandle;
# open "file.annotated"
unless ($fh->open (qq{$mut_file})) { die "Could not open mutation project file '$mut_file' for reading"; }
my $header = <$fh>;   # place a single line into $line
seek($fh, -length($header), 1); # place the same line back onto the filehandle
$parse_args{'version'} = $mutversion;
print "Parsing mutation file...\n";
$DB::single = 1;
my $mutation = $parser->Parse ($fh, $mut_file, %parse_args);
#  $parser->Write(*STDOUT);
$fh->close;
print "Done Parsing Mutation File! Yippee!\n";

#__DEBUGS
#  print "DATA:\n";
#  print Dumper ($cosmic);
#  print "DATA:\n";
#  print Dumper $mutation;
#  exit;

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

print SUMMARY "Line_Number\t$fileline{'1'}\tCosmic_Results (AA listed as residue1, res_start, residue2)\tOMIM_Results\tWarning: Input file must input all transcript names for each gene or else COSMIC and OMIM results may be invalid\n";

foreach my $hugo (sort keys %{$mutation}) {
foreach my $sample (keys %{$mutation->{$hugo}}) {
foreach my $line_num (keys %{$mutation->{$hugo}->{$sample}}) {
print STDOUT ".";   #report that we are starting a sample (For commandline user feedback)
#read in the alleles. The keys may change with future file formats. If so, a new version should be added to
#MG::Transform::Process::MutationCSV with a header translation

#            'gene_name' => 'HUGO_SYMBOL',
#            'strand' => 'TUMOR_SAMPLE_ID', # meaningless proxy -- see above

my ($entrez_gene_id, $line, $aa_change,$transcript,
   $mstatus,$Variant_Type,$Chromosome,$Start_position,$End_position,$Reference_Allele,$Tumor_Seq_Allele1,$gene) =
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
   if ($entrez_gene_id && exists($egi_exclude{$entrez_gene_id})) {
	   next;
   }
   if($mutversion eq 'aml' || $mutversion eq 'crossplatform') {
#set the the type to SNP if it is an aml file
	   $Variant_Type = 'SNP';
   }
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
	   my ($residue1, $res_start, $residue2, $res_stop, $new_residue) = @{Genome::Model::Tools::Annotate::AminoAcidChange::check_amino_acid_change_string(amino_acid_change_string => $aa_change)};
	   if(!$residue2 || $residue2 eq ' '){
		print "Skipping Silent Mutation";
#		my $createspreadsheet = "$hugo\t$transcript\t$Chromosome\t$Start_position\t$End_position\t$Reference_Allele\t$Tumor_Seq_Allele1\t$aa_change\t$Variant_Type\tSkipped - Silent Mutation\tSkipped - Silent Mutation";
		my $createspreadsheet = "$line_num\t$fileline{$line_num}\tSkipped - Silent Mutation\tSkipped - Silent Mutation";
		print SUMMARY "$createspreadsheet\n";
		next; #skip silent mutations
	   }
		   my $cosmic_hugo = CosmicHugo($cosmic,$hugo);
	   if (!defined($aa_change) || $aa_change eq 'NULL') {
##try with genomic
		   my $find_type;
		   unless(defined($Start_position) && defined($End_position)) {
			   $results_hash{NT}{NOMATCH} = "No nucleotide input";
			   next;
		   }
		   if(exists($cosmic->{$cosmic_hugo})) {
			   $find_type = FindCosmicGenomic($cosmic, $cosmic_hugo,
					   $Start_position,$End_position,$Reference_Allele,$proper_allele);

		   }
		   if(defined($find_type)) {
			   if ($find_type eq 'position_nucleotide') {
				   $results_hash{NT}{MATCH}{COSMIC}{$transcript} = ": Nucleotide";
			   } 
			   elsif ($find_type eq 'position') {
				   $results_hash{NT}{POSITION}{COSMIC}{$transcript}=": Nucleotide";
			   } 
			   else {
				   $results_hash{NT}{NOVEL}{COSMIC}{$transcript}=": Nucleotide";
			   }
		   }
		   else {
			   if (-e "$cosmic_dir/$hugo\.csv") {
				   $results_hash{NT}{NOVEL}{COSMIC}{$transcript}=": No Cosmic Nucleotide";
			   } 
			   else {
				   $results_hash{NT}{NOVEL}{COSMIC}{$transcript}=": No Cosmic File";
			   }
		   }
		   next;
	   }

#retrieve OMIM match
	   my $omim_find_type;
	   my $omim = \%omimaa;
	   if (exists($omim->{$hugo})) {
		   $omim_find_type = FindOMIM(\%omimaa,$hugo,
				   $res_start,$res_stop,
				   $residue1,$residue2);
	   }

#retrieve COSMIC match
           my $cosmic_find_type;
           my @aa_holder;
           if (exists($cosmic->{$cosmic_hugo})) {
               ($cosmic_find_type, @aa_holder) = FindCosmic($cosmic,$cosmic_hugo,
                   $res_start,$res_stop,
                   $residue1,$residue2);
           }
	   my $matched = 0;
#Add COSMIC result to the results hash
	   if(defined($cosmic_find_type)) {
		   if ($cosmic_find_type eq 'position_aminoacid') {
			   $results_hash{AA}{MATCH}{COSMIC}{$transcript} = ": Amino Acid";
			   $matched++;
		   } 
		   elsif ($cosmic_find_type eq 'position') {
			   $results_hash{AA}{POSITION}{COSMIC}{$transcript}=": Amino Acid";
		   } 
		   else {
			   $results_hash{AA}{NOVEL}{COSMIC}{$transcript}=": Amino Acid -> Known AA = @aa_holder";
		   }
	   } 
	   else {
		   if (-e "$cosmic_dir/$hugo\.csv") {
			   $results_hash{AA}{NOVEL}{COSMIC}{$transcript}=": No Cosmic Amino Acid";
		   } else {
			   $results_hash{AA}{NOVEL}{COSMIC}{$transcript}=": Amino Acid - Cosmic Gene Name Not Found";
		   }
	   }

#Add OMIM result to the results hash
	   if(defined($omim_find_type)) {
		   if ($omim_find_type eq 'position_aminoacid') {
			   $results_hash{AA}{MATCH}{OMIM}{$transcript} =": Amino Acid";
			   $matched++;
		   } 
		   elsif ($omim_find_type eq 'position') {
			   $results_hash{AA}{POSITION}{OMIM}->{$transcript}=": Amino Acid";
		   } 
		   else {
			   $results_hash{AA}{NOVEL}{OMIM}->{$transcript}=": Amino Acid";
		   }
	   } 
	   else {
		   $results_hash{AA}{NOVEL}{OMIM}->{$transcript}=": Amino Acid - OMIM Gene Name Not Found";
	   }
#dont output matched hits?
#	   if($matched) {
#		   last;
#	   }

#now check to see what the 'best' cosmic score was
	   $cosmic_results{$line_num} = score_results(\%results_hash, "COSMIC");
	   $omim_results{$line_num} = score_results(\%results_hash, "OMIM");

my $createspreadsheet = "$line_num\t$fileline{$line_num}\t$cosmic_results{$line_num}\t$omim_results{$line_num}";
#	   my $createspreadsheet = "$hugo\t$transcript\t$Chromosome\t$Start_position\t$End_position\t$Reference_Allele\t$Tumor_Seq_Allele1\t$aa_change\t$Variant_Type\t$cosmic_results{$line_num}\t$omim_results{$line_num}";
	   print SUMMARY "$createspreadsheet\n";
   }
}
}
}
close(SUMMARY);
return 1;
}




################################################################################
#                                                                              #
#                            S U B R O U T I N E S                             #
#                                                                              #
################################################################################

sub CosmicHugo {
	my ($cosmic, $hugo) = @_;
	if (exists($cosmic->{$hugo})) {
		return $hugo;
	}
# check for UPPERCASE hugo match
	my $uc_hugo = uc($hugo);
	if (exists($cosmic->{$uc_hugo})) {
		return $uc_hugo;
	}
# check for UPPERCASE keys match
	foreach my $key (keys %{$cosmic}) {
		if ($uc_hugo eq uc($key)) {
			return $key;
		}
	}
	return '';
}

sub FindCosmic {
	my ($cosmic, $hugo,
			$res_start, $res_stop, $residue1, $residue2) = @_;

	my $return_value = 'no_match';
	unless (exists($cosmic->{$hugo})) {
		warn "No cosmic entry for: $hugo";
		return $return_value;
	}
	my $aa_novel;
	my $aa_novel2;
	foreach my $sample (keys %{$cosmic->{$hugo}}) {
		if (defined $cosmic->{$hugo}->{$sample}->{res_start}){
			if ($cosmic->{$hugo}->{$sample}->{res_start} == $cosmic->{$hugo}->{$sample}->{res_stop}){
				$aa_novel2 = $aa_novel2." || ".$cosmic->{$hugo}->{$sample}->{residue1}.$cosmic->{$hugo}->{$sample}->{res_start}.$cosmic->{$hugo}->{$sample}->{residue2};
			unless (defined($cosmic->{$hugo}->{$sample}->{residue1})){
				print "res1undef";
			}
			unless (defined($cosmic->{$hugo}->{$sample}->{residue2})){
				print "res2undef";
			}
			unless (defined($aa_novel2)){
				print "aanovel2undef";
			}

			}
			else {
			$aa_novel2 = $aa_novel2." || ".$cosmic->{$hugo}->{$sample}->{residue1}.$cosmic->{$hugo}->{$sample}->{res_start}."-".$cosmic->{$hugo}->{$sample}->{res_stop}.$cosmic->{$hugo}->{$sample}->{residue2};
			}

			my @aa_novel = ( split (/ \|+ /, $aa_novel2));
			my %counts = ();
			my @countfinal;
			for (@aa_novel) {
			   $counts{$_}++;
			}
			foreach my $keys (keys %counts) {
			   @countfinal = (@countfinal,"$keys ($counts{$keys})");
			   $aa_novel = join(" || ",@countfinal);
			}
		}
		# Test that it at least matches position
		if (exists($cosmic->{$hugo}->{$sample}->{res_start}) &&
				exists($cosmic->{$hugo}->{$sample}->{res_stop}) &&
				defined($cosmic->{$hugo}->{$sample}->{res_start}) &&
				defined($cosmic->{$hugo}->{$sample}->{res_stop}) &&
				$cosmic->{$hugo}->{$sample}->{res_start} == $res_start &&
				$cosmic->{$hugo}->{$sample}->{res_stop} == $res_stop) {
			$return_value = 'position';
			# Test that it matches both
			if (exists($cosmic->{$hugo}->{$sample}->{residue1}) &&
					exists($cosmic->{$hugo}->{$sample}->{residue2}) &&
					defined($cosmic->{$hugo}->{$sample}->{residue1}) &&
					defined($cosmic->{$hugo}->{$sample}->{residue2}) &&
					uc($cosmic->{$hugo}->{$sample}->{residue1}) eq uc($residue1) &&
					uc($cosmic->{$hugo}->{$sample}->{residue2}) eq uc($residue2)) {
				return 'position_aminoacid';
			}
		}
	}
	$aa_novel =~ s/^\s+//;
	$aa_novel =~ s/^\(1\)\s\|+//g;
	$aa_novel =~ s/^\s+//;
	return ($return_value,$aa_novel);
}

sub FindCosmicGenomic {
	my ($cosmic, $hugo,
			$genomic_start, $genomic_stop, $nt1, $nt2) = @_;

	my $return_value = 'no_match';
	unless (exists($cosmic->{$hugo})) {
		warn "No cosmic entry for: $hugo";
		return $return_value;
	}
	foreach my $sample (keys %{$cosmic->{$hugo}}) {
		# Test that it at least matches position
		if (exists($cosmic->{$hugo}->{$sample}->{genome_start}) &&
				exists($cosmic->{$hugo}->{$sample}->{genome_stop}) &&
				defined($cosmic->{$hugo}->{$sample}->{genome_start}) &&
				defined($cosmic->{$hugo}->{$sample}->{genome_stop}) &&
				$cosmic->{$hugo}->{$sample}->{genome_start} == $genomic_start &&
				$cosmic->{$hugo}->{$sample}->{genome_stop} == $genomic_stop) {
			$return_value = 'position';
			# Test that it matches both
			if (exists($cosmic->{$hugo}->{$sample}->{nucleotide}) &&
					defined($cosmic->{$hugo}->{$sample}->{nucleotide})) {
				my ($start,$stop,$type_length,$type,$reference,$mutant) = parse_nucleotide($cosmic->{$hugo}->{$sample}->{nucleotide});
				if($reference eq $nt1 && $mutant eq $nt2) {
					return 'position_nucleotide';
				}
			}
		}
	}
	return $return_value;
}

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
	}
	return $return_value;
}

sub score_results {
	my ($results, $database) = @_;

	if(exists($results->{AA}{MATCH}->{$database})) {
#best hit was a MATCH. Huzzah!
		my ($transcript) = keys %{$results->{AA}{MATCH}{$database}};
		return ("Match".$results->{AA}{MATCH}->{$database}{$transcript});
	}
	elsif(exists($results->{AA}{POSITION}->{$database})) {
#best hit was a position match
		my ($transcript) = keys %{$results->{AA}{POSITION}{$database}};
		return ("Position Match".$results->{AA}{POSITION}->{$database}{$transcript});
	}
	elsif(exists($results->{AA}{NOVEL}->{$database})) {
		my ($transcript) = keys %{$results->{AA}{NOVEL}{$database}};
		return ("Novel".$results->{AA}{NOVEL}->{$database}{$transcript});
	}
	elsif(exists($results->{NT}{MATCH}->{$database})) {
#best hit was a MATCH. Huzzah!
		my ($transcript) = keys %{$results->{NT}{MATCH}{$database}};
		return ("Match".$results->{NT}{MATCH}->{$database}{$transcript});
	}
	elsif(exists($results->{NT}{POSITION}->{$database})) {
#best hit was a position match
		my ($transcript) = keys %{$results->{NT}{POSITION}{$database}};
		return ("Position Match".$results->{NT}{POSITION}->{$database}{$transcript});
	}
	elsif(exists($results->{NT}{NOVEL}->{$database})) {
		my ($transcript) = keys %{$results->{NT}{NOVEL}{$database}};
		return ("Novel".$results->{NT}{NOVEL}->{$database}{$transcript});
	}
	else {
#it was a nomatch!
		my ($transcript) = keys %{$results->{NOMATCH}};
		my $ret_value = (defined($transcript) && $results->{NOMATCH}{$transcript}) ?  $results->{NOMATCH}{$transcript} : "Unknown/NULL";
		return $ret_value;
	}
}

sub LoadCosmicFiles {
	my ($cosmic_parser,@cosmic_files) = @_;
	my ($cosmic,$done,$percent_done);
	print STDOUT "Parsing " . scalar(@cosmic_files) . " files...\n";
	foreach my $cosmic_file (@cosmic_files) {
		my $cosmic_fh = new FileHandle;
		unless ($cosmic_fh->open (qq{$cosmic_file})) {
			die "Could not open transcript file '$cosmic_file' for reading";
		}
		my %parse_args = (check => 0, all => 1, no_process =>1);
		$cosmic = $cosmic_parser->Parse($cosmic_fh,$cosmic_file,%parse_args);
#__CLOSE INPUT FILE
		$cosmic_fh->close;
		$done += 1;
		$percent_done = 100 * $done / scalar(@cosmic_files);
		printf STDOUT "%0.f%% Done!\r",$percent_done;

	}
	print STDOUT "\n";
	return $cosmic;
}

sub parse_nucleotide {
	my ($string) = @_;
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
			warn "Intronic mutation. \n";
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

####################################
#  LOAD AND CHECKSUM COSMIC FILES  #
####################################

sub load_and_checksum_cosmic_files {
	my ($cosmic_archive_file,
			$cosmic_dir, $checksum, $cosmic_parser, @cosmic_files) = @_;

#__CALL METHOD TO LOAD COSMIC FILES
	my $cosmic = LoadCosmicFiles ($cosmic_parser, @cosmic_files);

#__CHECKSUM THIS LOAD
	$cosmic->{PARSER_CHECKSUM} = $checksum;
	Storable::store ($cosmic, $cosmic_archive_file);
	my $checksum_file = new FileHandle;
	$checksum_file->open ("$cosmic_dir/.parser_md5_checksum","w") ||
		die "Couldn't open checksum file for writing\n";
	print $checksum_file "$checksum";
	$checksum_file->close();

#__RETURN OBJECT
	return $cosmic;
}

################################################################################
#                                                                              #
#                      P O D   D O C U M E N T A T I O N                       #
#                                                                              #
################################################################################

=head1 NAME

gt_annotated_mutation_versus_known -- compares the amino acid changes in a .annotated file to the entries (if present) in the COSMIC and OMIM files

=head1 SYNOPSIS

$ compare_mutations --mutation test.annotated --omimaa /gscuser/dlarson/code/database/cosmic/OMIM/omim_aa.csv --cosmic-dir /gscuser/dlarson/code/database/cosmic/COSMIC/cosmic/ --basename TEST_comparemutations --mutversion=from_genome_tools

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
