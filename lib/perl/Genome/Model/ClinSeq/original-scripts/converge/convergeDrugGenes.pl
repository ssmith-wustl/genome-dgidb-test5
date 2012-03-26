#!/usr/bin/perl
#Written by Malachi Griffith
#For a group of ClinSeq models, converge various types of Druggable genes results

#Consider the following event types (individually, and then together):
#SNVs, InDels, CNV amplifications, fusion genes, etc.
#Create a summary at the gene level

#Create a separate report for known druggable (e.g. DrugBank) and potentially druggable genes (e.g. kinases, etc.)
#For potentially druggable summarize to Gene level as well as the Gene-Family level

#Create a series of final reports that list genes/drugs and summarizes totals
# - genes with each kind of event
# - genes with any event
# - patients with at least 1 druggable gene (each type of event - then all event types together)
# - drugs indicated in at least 1 patient, 2 patients, etc.
# - total number of drugs

use strict;
use warnings;
use Getopt::Long;
use Term::ANSIColor qw(:constants);
use Data::Dumper;
use Genome;

my $lib_dir;
my $script_dir;
use Cwd 'abs_path';
BEGIN{
  if (abs_path($0) =~ /(.*\/)(.*\/).*\.pl/){
    $lib_dir = $1;
    $script_dir = $1.$2;
  }
}
use lib $lib_dir;
use ClinSeq qw(:all);
use converge::Converge qw(:all);

my $build_ids = '';
my $model_ids = '';
my $model_group_id = '';
my $filter_name = '';
my $outdir = '';
my $verbose = 0;

GetOptions ('build_ids=s'=>\$build_ids, 'model_ids=s'=>\$model_ids, 'model_group_id=s'=>\$model_group_id,
            'filter_name=s'=>\$filter_name, 'outdir=s'=>\$outdir, 'verbose=i'=>\$verbose);

my $usage=<<INFO;
  Example usage: 

  convergeDrugGenes.pl  --model_group_id='31779'  --filter_name='antineo'  --outdir=/gscmnt/sata132/techd/mgriffit/luc/druggable_genes/  --verbose=1

  Specify *one* of the following as input (each model/build should be a ClinSeq model)
  --build_ids                Comma separated list of specific build IDs
  --model_ids                Comma separated list of specific model IDs
  --model_group_id           A single genome model group ID
  --filter_name              The name appended to each file indicating which filter was applied
  --outdir                   Path of the a directory for output files
  --verbose                  More descriptive stdout messages

  Test Clinseq model groups:
  31779                      LUC17 project

INFO

unless (($build_ids || $model_ids || $model_group_id) && $filter_name && $outdir){
  print RED, "\n\nRequired parameter missing", RESET;
  print GREEN, "\n\n$usage", RESET;
  exit(1);
}

#Set output file names
$outdir = &checkDir('-dir'=>$outdir, '-clear'=>"no");
my $known_gene_drug_table = $outdir . "KnownGeneDrugTable.tsv";
my $known_interaction_table = $outdir . "KnownInteractionTable.tsv";

#Get the models/builds
if ($verbose){print BLUE, "\n\nGet genome models/builds for supplied list", RESET;}
my $models_builds;
if ($build_ids){
  my @build_ids = split(",", $build_ids);
  $models_builds = &getModelsBuilds('-builds'=>\@build_ids, '-verbose'=>$verbose);
}elsif($model_ids){
  my @model_ids = split(",", $model_ids);
  $models_builds = &getModelsBuilds('-models'=>\@model_ids, '-verbose'=>$verbose);
}elsif($model_group_id){
  $models_builds = &getModelsBuilds('-model_group_id'=>$model_group_id, '-verbose'=>$verbose);
}else{
  print RED, "\n\nCould not obtains models/builds - check input to convergeCufflinksExpression.pl\n\n", RESET;
  exit();
}

#Get files:
# - drug-gene interaction files for each event type
# - annotated files for each event type containing potentially druggable results
my $dgidb_subdir_name = "drugbank";
my $files = &getFiles('-models_builds'=>$models_builds, '-filter_name'=>$filter_name, '-dgidb_subdir_name'=>$dgidb_subdir_name);

#Go through each event type for each patient and parse out the values needed.
my @event_types = qw (snv indel cnv_gain rna_cufflinks_absolute rna_tophat_absolute);

#Known druggable ge
my $k_result = &parseKnownDruggableFiles('-files'=>$files, '-event_types'=>\@event_types);
my $k_g = $k_result->{'genes'}; #Known druggable genes
my $k_i = $k_result->{'interactions'}; #Known druggable gene interactions
#print Dumper $k_g;

#Define potentially druggable families
#TODO: Do not hard code these groupings of gene list names here.  Either do all of this using DGIdb
#Or at least define the meta groups in the same location as where the gene lists are stored and load them here.
my %gene_families;
my @potentially_druggable = qw ( Druggable_RussLampel );
my @kinases = qw ( Kinases KinasesGO ProteinKinaseEntrezQuery LipidKinaseActivity_GO0001727 ProteinSerineThreonineKinaseActivity_GO0004674 ProteinTyrosineKinaseActivity_GO0004713 TyrosineKinaseEntrezQuery );
my @ion_channels = qw ( IonChannelActivity_GO0005216 ); 
my @phosphatases = qw ( PhospoproteinPhosphataseActivity_GO0004721 PhosphataseEntrezQuery ); 
my @gpcrs = qw ( GpcrActivity_GO0045028 );
my @phospholipases = qw ( PhospholipaseActivity_GO0004620 );
my @peptidases = qw ( PeptidaseInhibitorActivity_GO0030414 );
my @transporter = qw ( TransporterActivity_GO0005215 IonChannelActivity_GO0005216 );
my @growth_factors = qw ( GrowthFactorActivity_GO0008083 );
my @hormone_related = qw ( HormoneActivity_GO000517 NuclearHormoneReceptor_GO0004879 );
my @cell_surface = qw ( CellSurface_GO0009986 ExternalSideOfPlasmaMembrane_GO0009897  );
my @response_to_drug = qw ( DrugMetabolism_GO0017144 TransporterActivity_GO0005215 ResponseToDrug_GO0042493 );
my @transcription_factors = qw ( TfcatTransFactors FactorBookTransFactors TranscriptionFactorBinding_GO0008134 TranscriptionFactorComplex_GO0005667 );
my @cancer_genes = qw ( CancerGeneCensus FutrealEtAl2004Review HahnAndWeinberg2002Review Mitelman2000Review VogelsteinAndKinzler2004Review OncogeneEntrezQuery TumorSuppresorEntrezQuery );
my @oncogenes = qw ( OncogeneEntrezQuery );
my @tumor_suppressors = qw ( TumorSuppresorEntrezQuery RegulationOfCellCycle_GO0051726 );
my @dna_repair = qw ( DnaRepair_GO0006281 );
my @cancer_pathway = qw ( Alpha6Beta4IntegrinPathway AndrogenReceptorPathway EGFR1Pathway HedgehogPathway IDPathway KitReceptorPathway NotchPathway TGFBRPathway TNFAlphaNFkBPathway WntPathway );
my @egfr_pathway = qw ( EGFR1Pathway );
my @histone_related = qw ( HistoneModification_GO0016570 );
my @genome_stability = qw ( StabilityEntrezQuery );

$gene_families{'Potentially Druggable'} = \@potentially_druggable;
$gene_families{'Kinase'} = \@kinases;
$gene_families{'Ion Channel'} = \@ion_channels;
$gene_families{'Phophatase'} = \@phosphatases;
$gene_families{'GPCR'} = \@gpcrs;
$gene_families{'Phospholipase'} = \@phospholipases;
$gene_families{'Peptidase'} = \@peptidases;
$gene_families{'Transporter'} = \@transporter;
$gene_families{'Growth Factor'} = \@growth_factors;
$gene_families{'Hormone Related'} = \@hormone_related;
$gene_families{'Cell Surface'} = \@cell_surface;
$gene_families{'Response To Drug'} = \@response_to_drug;
$gene_families{'Transcription Factor'} = \@transcription_factors;
$gene_families{'Cancer Gene'} = \@cancer_genes;
$gene_families{'Oncogene'} = \@oncogenes;
$gene_families{'Tumor Suppressors'} = \@tumor_suppressors;
$gene_families{'DNA Repair'} = \@dna_repair;
$gene_families{'Cancer Pathway'} = \@cancer_pathway;
$gene_families{'EGFR Pathway'} = \@egfr_pathway;
$gene_families{'Histone Related'} = \@histone_related;
$gene_families{'Genome Stability'} = \@genome_stability;

print Dumper %gene_families;


my $p_result = &parsePotentiallyDruggableFiles('-files'=>$files, '-event_types'=>\@event_types);
 


#Generate a header for the event types output columns
my @et_header;
foreach my $et (@event_types){
	push(@et_header, "$et"."_sample_count");
	push(@et_header, "$et"."_sample_list");
}
my $et_header_s = join("\t", @et_header);


#A.) Generate Gene -> patient events <- known drugs table (all drugs that target that gene)
print BLUE, "\n\nWriting (gene -> patient events <- known drugs) table to: $known_gene_drug_table", RESET;
open (OUT, ">$known_gene_drug_table") || die "\n\nCould not open output file: $known_gene_drug_table\n\n";
print OUT "gene\tgene_name\tgrand_patient_count\tgrand_patient_list\tdrug_count\tdrug_list\t$et_header_s\n";
foreach my $gene (sort keys %{$k_g}){
	my $gene_name = $k_g->{$gene}->{gene_name};
	my $grand_patient_list = $k_g->{$gene}->{grand_list};
	my $grand_patient_count = keys %{$grand_patient_list};
	my @grand_patient_list = keys %{$grand_patient_list};
	my @tmp = sort { substr($a, &lengthOfAlpha($a)) <=> substr($b, &lengthOfAlpha($b)) } @grand_patient_list;;
	my $grand_patient_list_s = join (",", @tmp);
	my $drug_list = $k_g->{$gene}->{drug_list};
	my $drug_count = keys %{$drug_list};
	my @drug_list = keys %{$drug_list};
	@tmp = sort @drug_list;
  my $drug_list_s = join(",", @tmp);

	my @et_values;
	foreach my $et (@event_types){
		if (defined($k_g->{$gene}->{$et})){
			my %patients = %{$k_g->{$gene}->{$et}->{patient_list}};
			my @patient_list = keys %patients;
			my @tmp = sort { substr($a, &lengthOfAlpha($a)) <=> substr($b, &lengthOfAlpha($b)) } @patient_list;;
      my $patient_list_s = join (",", @tmp);
			my $patient_count = scalar(@patient_list);
			push(@et_values, $patient_count);
			push(@et_values, $patient_list_s);
		}else{
			push(@et_values, 0);
			push(@et_values, "NA");
		}
	}
	my $et_values_s = join("\t", @et_values);
	print OUT "$gene\t$gene_name\t$grand_patient_count\t$grand_patient_list_s\t$drug_count\t$drug_list_s\t$et_values_s\n";
}
close(OUT);


#B.) Generate Interaction -> patient events <- known drug table (only the one drug of the interaction)
print BLUE, "\n\nWriting (interaction -> patient events <- known drug) table to: $known_interaction_table", RESET;
open (OUT, ">$known_interaction_table") || die "\n\nCould not open output file: $known_interaction_table\n\n";
print OUT "gene\tgene_name\tgrand_patient_count\tgrand_patient_list\tdrug_count\tdrug_list\t$et_header_s\n";
foreach my $interaction (sort keys %{$k_i}){
  my $mapped_gene_name = $k_i->{$interaction}->{mapped_gene_name};
	my $gene_name = $k_i->{$interaction}->{gene_name};
	my $grand_patient_list = $k_i->{$interaction}->{grand_list};
	my $grand_patient_count = keys %{$grand_patient_list};
	my @grand_patient_list = keys %{$grand_patient_list};
	my @tmp = sort { substr($a, &lengthOfAlpha($a)) <=> substr($b, &lengthOfAlpha($b)) } @grand_patient_list;;
	my $grand_patient_list_s = join (",", @tmp);
	my $drug_list_s = $k_i->{$interaction}->{drug_name};

	my @et_values;
	foreach my $et (@event_types){
		if (defined($k_i->{$interaction}->{$et})){
			my %patients = %{$k_i->{$interaction}->{$et}->{patient_list}};
			my @patient_list = keys %patients;
			my @tmp = sort { substr($a, &lengthOfAlpha($a)) <=> substr($b, &lengthOfAlpha($b)) } @patient_list;;
      my $patient_list_s = join (",", @tmp);
			my $patient_count = scalar(@patient_list);
			push(@et_values, $patient_count);
			push(@et_values, $patient_list_s);
		}else{
			push(@et_values, 0);
			push(@et_values, "NA");
		}
	}
	my $et_values_s = join("\t", @et_values);
	print OUT "$mapped_gene_name\t$gene_name\t$grand_patient_count\t$grand_patient_list_s\t1\t$drug_list_s\t$et_values_s\n";
}
close(OUT);









print "\n\n";

exit();


############################################################################################################################
#Determine length of non-numeric portion of an alphanumeric string                                                         #
############################################################################################################################
sub lengthOfAlpha{
	my ($input) = @_;
	my ($alpha) = $input =~ /(\D{1,})/;
	my $length = length($alpha);
	return ($length);
}


############################################################################################################################
#Get input files to be parsed                                                                                              #
############################################################################################################################
sub getFiles{
  my %args = @_;
  my $models_builds = $args{'-models_builds'};
  my $filter_name = $args{'-filter_name'};
  my $dgidb_subdir_name = $args{'-dgidb_subdir_name'};
  my %files;

  if ($verbose){print BLUE, "\n\nGet annotation files and drug-gene interaction files from these builds", RESET;}
  my %mb = %{$models_builds->{cases}};
  foreach my $c (keys %mb){
    my $b = $mb{$c}{build};
    my $m = $mb{$c}{model};
    my $build_directory = $b->data_directory;
    my $subject_name = $b->subject->name;
    my $subject_common_name = $b->subject->common_name;
    my $build_id = $b->id;

    #If the subject name is not defined, die
    unless ($subject_name){
      print RED, "\n\nCould not determine subject name for build: $build_id\n\n", RESET;
      exit(1);
    }

    my $final_name = "Unknown";
    if ($subject_name){$final_name = $subject_name;}
    if ($subject_common_name){$final_name = $subject_common_name;}
    if ($verbose){print BLUE, "\n\t$final_name\t$build_id\t$build_directory", RESET;}

    my $topdir = "$build_directory"."/$final_name/";

    #Some event types could have come from exome, wgs, or wgs_exome... depending on the event type allow these options and check in order

    #1.) Look for SNV files
    my @snv_subdir_options = qw (wgs_exome wgs exome);
    my $snv_annot_file_name = "snvs.hq.tier1.v1.annotated.compact.tsv";
    my $snv_drug_file_name = "snvs.hq.tier1.v1.annotated.compact.dgidb."."$filter_name".".tsv";
    foreach my $dir_name (@snv_subdir_options){
      my $annot_file_path = $topdir . "snv/$dir_name/$snv_annot_file_name";
      my $drug_file_path = $topdir . "snv/$dir_name/dgidb/$dgidb_subdir_name/$snv_drug_file_name";
      #If a file was already found, do nothing
      unless (defined($files{$final_name}{snv}{annot_file_path})){
        #If both files are present, store for later
        if (-e $annot_file_path && -e $drug_file_path){
          $files{$final_name}{snv}{annot_file_path} = $annot_file_path;
          $files{$final_name}{snv}{drug_file_path} = $drug_file_path;
        }
      }
    }
    #Make sure at least one pair of files was found
    unless (defined($files{$final_name}{snv}{annot_file_path}) && defined($files{$final_name}{snv}{drug_file_path})){
      print RED, "\n\nCould not find SNV drug-gene and annotation files for $final_name ($subject_name - $subject_common_name) in:\n\t$build_directory\n\n", RESET;
      exit(1);
    }

    #2.) Look for InDel files
    my @indel_subdir_options = qw (wgs_exome wgs exome);
    my $indel_annot_file_name = "indels.hq.tier1.v1.annotated.compact.tsv";
    my $indel_drug_file_name = "indels.hq.tier1.v1.annotated.compact.dgidb."."$filter_name".".tsv";
    foreach my $dir_name (@indel_subdir_options){
      my $annot_file_path = $topdir . "indel/$dir_name/$indel_annot_file_name";
      my $drug_file_path = $topdir . "indel/$dir_name/dgidb/$dgidb_subdir_name/$indel_drug_file_name";
      #If a file was already found, do nothing
      unless (defined($files{$final_name}{indel}{annot_file_path})){
        #If both files are present, store for later
        if (-e $annot_file_path && -e $drug_file_path){
          $files{$final_name}{indel}{annot_file_path} = $annot_file_path;
          $files{$final_name}{indel}{drug_file_path} = $drug_file_path;
        }
      }
    }
    #Make sure at least one was found
    unless (defined($files{$final_name}{indel}{annot_file_path}) && defined($files{$final_name}{indel}{drug_file_path})){
      print RED, "\n\nCould not find INDEL drug-gene and annotation files for $final_name ($subject_name - $subject_common_name) in:\n\t$build_directory\n\n", RESET;
      exit(1);
    }

    #3.) Look for CNV gain files
    my $cnv_gain_annot_file_name = "cnv.Ensembl_v58.amp.tsv";
    my $cnv_gain_drug_file_name = "cnv.Ensembl_v58.amp.dgidb."."$filter_name".".tsv";

    my $annot_file_path = $topdir . "cnv/$cnv_gain_annot_file_name";
    my $drug_file_path = $topdir . "cnv/dgidb/$dgidb_subdir_name/$cnv_gain_drug_file_name";
    if (-e $annot_file_path && -e $drug_file_path){
      $files{$final_name}{cnv_gain}{annot_file_path} = $annot_file_path;
      $files{$final_name}{cnv_gain}{drug_file_path} = $drug_file_path;
    }else{
      print RED, "\n\nCould not find INDEL drug-gene and annotation files for $final_name ($subject_name - $subject_common_name) in:\n\t$build_directory\n\n", RESET;
      exit(1);
    }

    #4.) Look for Cufflinks RNAseq outlier expression files 
    my $rna_cufflinks_annot_file_name = "isoforms.merged.fpkm.expsort.top1percent.tsv";
    my $rna_cufflinks_drug_file_name = "isoforms.merged.fpkm.expsort.top1percent.dgidb."."$filter_name".".tsv";

    $annot_file_path = $topdir . "rnaseq/tumor/cufflinks_absolute/isoforms_merged/$rna_cufflinks_annot_file_name";
    $drug_file_path = $topdir . "rnaseq/tumor/cufflinks_absolute/isoforms_merged/dgidb/$dgidb_subdir_name/$rna_cufflinks_drug_file_name";
    if (-e $annot_file_path && -e $drug_file_path){
      $files{$final_name}{rna_cufflinks_absolute}{annot_file_path} = $annot_file_path;
      $files{$final_name}{rna_cufflinks_absolute}{drug_file_path} = $drug_file_path;
    }else{
      print RED, "\n\nCould not find Cufflinks Absolute drug-gene and annotation files for $final_name ($subject_name - $subject_common_name) in:\n\t$build_directory\n\t$annot_file_path\n\t$drug_file_path\n\n", RESET;
      exit(1);
    }

    #5.) Look for Tophat junction RNAseq outlier expression files
    my $rna_tophat_annot_file_name = "Ensembl.Junction.GeneExpression.top1percent.tsv";
    my $rna_tophat_drug_file_name = "Ensembl.Junction.GeneExpression.top1percent.dgidb."."$filter_name".".tsv";

    $annot_file_path = $topdir . "rnaseq/tumor/tophat_junctions_absolute/$rna_tophat_annot_file_name";
    $drug_file_path = $topdir . "rnaseq/tumor/tophat_junctions_absolute/dgidb/$dgidb_subdir_name/$rna_tophat_drug_file_name";
    if (-e $annot_file_path && -e $drug_file_path){
      $files{$final_name}{rna_tophat_absolute}{annot_file_path} = $annot_file_path;
      $files{$final_name}{rna_tophat_absolute}{drug_file_path} = $drug_file_path;
    }else{
      print RED, "\n\nCould not find Tophat Absolute drug-gene and annotation files for $final_name ($subject_name - $subject_common_name) in:\n\t$build_directory\n\t$annot_file_path\n\t$drug_file_path\n\n", RESET;
      exit(1);
    }
  }
  return(\%files);
}


############################################################################################################################
#Parse known druggable files                                                                                               #
############################################################################################################################
sub parseKnownDruggableFiles{
  my %args = @_;
  my $files = $args{'-files'};
  my @event_types = @{$args{'-event_types'}};

  print BLUE, "\n\nParsing files containing known drug-gene interaction data", RESET;

	#Store all results organized by gene and separately by drug-gene interaction
  my %result;
  my %genes;
  my %interactions;

	#Note that the druggable files are already filtered down to only the variant affected genes with a drug interaction
  #To get a sense of the total number of events will have to wait until the annotation files are being proccessed 

  foreach my $patient (keys %{$files}){
    print BLUE, "\n\t$patient", RESET;
    foreach my $event_type (@event_types){
      my $drug_file_path = $files->{$patient}->{$event_type}->{drug_file_path};
      print BLUE, "\n\t\t$drug_file_path", RESET;

      open (IN, "$drug_file_path") || die "\n\nCould not open gene-drug interaction file: $drug_file_path\n\n";
      my $header = 1;
      my %columns;
      while(<IN>){
        chomp($_);
        my @line = split("\t", $_);
        if ($header){
          my $p = 0;
          foreach my $column (@line){
            $columns{$column}{position} = $p;
            $p++;
          }
          $header = 0;
          next();
        }
        my $gene_name = $line[$columns{'gene_name'}{position}];
        my $mapped_gene_name = $line[$columns{'mapped_gene_name'}{position}];
        my $drug_name = $line[$columns{'drug_name'}{position}];
        my $interaction = "$mapped_gene_name"."_"."$drug_name";
        $genes{$mapped_gene_name}{gene_name} = $gene_name;
        $interactions{$interaction}{gene_name} = $gene_name;
        $interactions{$interaction}{mapped_gene_name} = $mapped_gene_name;
        $interactions{$interaction}{drug_name} = $drug_name;

        #If the gene has any events it will be associated with all drugs that interact with that gene
        if (defined($genes{$mapped_gene_name}{drug_list})){
          my $drugs = $genes{$mapped_gene_name}{drug_list};
          $drugs->{$drug_name} = 1;
        }else{
          my %drugs;
          $drugs{$drug_name} = 1;
          $genes{$mapped_gene_name}{drug_list} = \%drugs;
        }

        #Add patient lists specific to this event type
        if (defined($genes{$mapped_gene_name}{$event_type})){
          my $patients = $genes{$mapped_gene_name}{$event_type}{patient_list};
          $patients->{$patient} = 1;
        }else{
          my %patients;
          $patients{$patient} = 1;
          $genes{$mapped_gene_name}{$event_type}{patient_list} = \%patients;
        }

        if (defined($interactions{$interaction}{$event_type})){
          my $patients = $interactions{$interaction}{$event_type}{patient_list};
          $patients->{$patient} = 1;
        }else{
           my %patients;
           $patients{$patient} = 1;
           $interactions{$interaction}{$event_type}{patient_list} = \%patients;
        }

        #Create or update the grand list of patients with ANY events hitting this gene
        if (defined($genes{$mapped_gene_name}{grand_list})){
          my $patients =$genes{$mapped_gene_name}{grand_list};
          $patients->{$patient} = 1;
        }else{
          my %patients;
          $patients{$patient} = 1;
          $genes{$mapped_gene_name}{grand_list} = \%patients;
        }

        if (defined($interactions{$interaction}{grand_list})){
          my $patients = $interactions{$interaction}{grand_list};
          $patients->{$patient} = 1;
        }else{
          my %patients;
          $patients{$patient} = 1;
          $interactions{$interaction}{grand_list} = \%patients;
        }

      }

      close(IN);
    }
  }
  $result{genes} = \%genes;
  $result{interactions} = \%interactions;

  return(\%result);
}




############################################################################################################################
#Parse annotation files (containing drug gene family information)                                                          #
############################################################################################################################
sub parsePotentiallyDruggableFiles{
  my %args = @_;
  my $files = $args{'-files'};
  my @event_types = @{$args{'-event_types'}};

  print BLUE, "\n\nParsing files containing potentially druggable genes data", RESET;

  #Store all results organized by gene and separately by gene family (e.g. kinases, ion channels etc.)
  my %result;
  my %genes;
  my %families;

	#Note that the annotation files contain all qualifying variant events (the associated gene may or may not belong to a gene family of interest)
  foreach my $patient (keys %{$files}){
    print BLUE, "\n\t$patient", RESET;
    foreach my $event_type (@event_types){
      my $annot_file_path = $files->{$patient}->{$event_type}->{annot_file_path};
      print BLUE, "\n\t\t$annot_file_path", RESET;

      open (IN, "$annot_file_path") || die "\n\nCould not open annotation file: $annot_file_path\n\n";
      my $header = 1;
      my %columns;
      while(<IN>){
        chomp($_);
        my @line = split("\t", $_);
        if ($header){
          my $p = 0;
          foreach my $column (@line){
            $columns{$column}{position} = $p;
            $p++;
          }
          $header = 0;
          next();
        }
        my $mapped_gene_name = $line[$columns{'mapped_gene_name'}{position}];
 



      }
    }
  }
}



