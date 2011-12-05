#!/usr/bin/perl
#Written by Malachi Griffith

#Load modules
use strict;
use warnings;
use above "Genome"; #Makes sure I am using the local genome.pm and use lib right above it (don't do this in a module)
use Getopt::Long;
use Term::ANSIColor qw(:constants);
use Data::Dumper;

my $script_dir;
use Cwd 'abs_path';
BEGIN{
  if (abs_path($0) =~ /(.*\/).*\.pl/){
    $script_dir = $1;
  }
}
use lib $script_dir;
use ClinSeq qw(:all);



#This script attempts to automate the process of running the 'clinseq' pipeline

#Input data (one or more of the following)
#1.) Whole genome somatic variation model id
#2.) Whole exome somatic variation model id
#3.) RNA-seq model id
#4.) Whole genome germline variation model id

#Big picture goals.
#1.) Summarize somatic and germline variation for a single tumor/normal pair
#2.) Specifically identify the events most likely to be useful in a clinical context (clinically actionable events) - Missense mutations, amplifications, over-expressed genes
#3.) Generate summary statistics files and figures that will serve as the input for a clincal genomics report to be generated downstream

#Specific goals - attempt to do all of the following in a fault tolerant fashion...
#1.) Summarize library statistics for each data type for both tumor/normal (where applicable) - WGS, Exome, RNA-seq
#    - Number of lanes of data, read counts, base counts, mapping rate, SNP concordance, expressed genes, etc.
#2.) Summarize WGS/exome somatic SNVs.  Produce a merged tier1 SNV file.
#3.) Get BAM read counts for somatic variants called from WGS/Exome data and add on BAM read counts from the RNA-seq data as well.
#4.) Summarize WGS/exome indels.  Annotate if neccessary.
#5.) Summarize WGS/exome SVs.  Annotate if neccessary.
#    - Produce a Circos plot
#6.) Summarize WGS CNVs by CNView
#7.) Summarize WGS CNVs by hmmCNV
#8.) Summarize RNA-seq gene fusions (defuse?)
#9.) Summarize RNA-seq outlier genes
#10.) Summarize RNA-seq differentially expressed genes
#11.) Produce a master list of candidate genes (mutated, amplified, over-expressed, differentially-expressed, gene-fusions)
#12.) Perform druggable genes analysis on the master list of candidate genes. Produce a master list of interactions but also breakdown further (e.g. antineoplastic drugs only)
#13.) Produce a clonality plot
#14.) Create single genome copy number plots (i.e. different from tumor vs. normal plots) - these help identify sample swaps, etc.
#NN.) Summarize germline SNV,  results for WGS data.
#NN.) Summarize LOH results for WGS data.

#General notes
#Any time a list is produced with gene names in it, attempt to fix these names to Entrez (translate ENSG ids where possible, etc.)


#Input parameters
my $wgs_som_var_model_id = '';
my $exome_som_var_model_id = '';
my $tumor_rna_seq_model_id = '';
my $normal_rna_seq_model_id = '';
my $working_dir = '';
my $common_name = '';
my $verbose = 0;
my $clean = 0;

GetOptions ('tumor_rna_seq_model_id=s'=>\$tumor_rna_seq_model_id, 'normal_rna_seq_model_id=s'=>\$normal_rna_seq_model_id,
	    'wgs_som_var_model_id=s'=>\$wgs_som_var_model_id, 'exome_som_var_model_id=s'=>\$exome_som_var_model_id, 
 	    'working_dir=s'=>\$working_dir, 'common_name=s'=>\$common_name, 'verbose=i'=>\$verbose, 'clean=i'=>\$clean);

my $usage=<<INFO;

  Example usage: 
  
  clinseq.pl  --wgs_som_var_model_id='2880644349'  --exome_som_var_model_id='2880732183'  --tumor_rna_seq_model_id='2880693923'  --working_dir=/gscmnt/sata132/techd/mgriffit/hgs/  --common_name='hg3'
  
  Intro:
  This script attempts to automate the process of running the 'clinseq' pipeline

  Details:
  --wgs_som_var_model_id          Whole genome sequence (WGS) somatic variation model ID
  --exome_som_var_model_id        Exome capture sequence somatic variation model ID
  --tumor_rna_seq_model_id        RNA-seq model id for the tumor sample
  --normal_rna_seq_model_id       RNA-seq model id for the normal sample
  --working_dir                   Directory where a patient subdir will be created
  --common_name                   Patient's common name (will be used for the name of a results dir and labeling purposes)
  --verbose                       To display more output, set to 1
  --clean                         To clobber the top dir and create everything from scratch, set to 1

INFO

unless (($wgs_som_var_model_id || $exome_som_var_model_id || $tumor_rna_seq_model_id || $normal_rna_seq_model_id) && $working_dir && $common_name){
  print GREEN, "$usage", RESET;
  exit();
}

my $step = 0;

#Set flags for each datatype
my ($wgs, $exome, $tumor_rnaseq, $normal_rnaseq) = (0,0,0,0);
if ($wgs_som_var_model_id){$wgs=1;}
if ($exome_som_var_model_id){$exome=1;}
if ($tumor_rna_seq_model_id){$tumor_rnaseq=1;}
if ($normal_rna_seq_model_id){$normal_rnaseq=1;}

#Check the working dir
$working_dir = &checkDir('-dir'=>$working_dir, '-clear'=>"no");

#Get Entrez and Ensembl data for gene name mappings
my $entrez_ensembl_data = &loadEntrezEnsemblData();

#Define reference builds - TODO: should determine this automatically from input builds
my $reference_build_ucsc = "hg19";
my $reference_build_ucsc_n = "19";
my $reference_build_ncbi = "build37";
my $reference_build_ncbi_n = "37";

#Directory of gene lists for various purposes
my $gene_symbol_lists_dir = "/gscmnt/sata132/techd/mgriffit/reference_annotations/GeneSymbolLists/";
$gene_symbol_lists_dir = &checkDir('-dir'=>$gene_symbol_lists_dir, '-clear'=>"no");

#Import a set of gene symbol lists (these files must be gene symbols in the first column, .txt extension, tab-delimited if multiple columns, one symbol per field, no header)
#Different sets of genes list could be used for different purposes
#Fix gene names as they are being imported
my @symbol_list_names1 = qw (Kinases KinasesGO CancerGeneCensus DrugBankAntineoplastic DrugBankInhibitors Druggable_RussLampel TfcatTransFactors FactorBookTransFactors);
$step++; print MAGENTA, "\n\nStep $step. Importing gene symbol lists (@symbol_list_names1)", RESET;
my $gene_symbol_lists1 = &importGeneSymbolLists('-gene_symbol_lists_dir'=>$gene_symbol_lists_dir, '-symbol_list_names'=>\@symbol_list_names1, '-entrez_ensembl_data'=>$entrez_ensembl_data, '-verbose'=>0);


#Create a hash for storing output files as they are created
my %out_paths; my $out_paths = \%out_paths;

#Make the patient subdir
$step++; print MAGENTA, "\n\nStep $step. Checking/creating the working dir for this patient", RESET;
my $patient_dir;
if ($clean){
  $patient_dir = &createNewDir('-path'=>$working_dir, '-new_dir_name'=>$common_name, '-force'=>"yes");
}else{
  $patient_dir = &createNewDir('-path'=>$working_dir, '-new_dir_name'=>$common_name);
}

#Get build directories for the three datatypes: $data_paths->{'wgs'}->*, $data_paths->{'exome'}->*, $data_paths->{'tumor_rnaseq'}->*
$step++; print MAGENTA, "\n\nStep $step. Getting data paths from 'genome' for specified model ids", RESET;
my $data_paths = &getDataDirs('-wgs_som_var_model_id'=>$wgs_som_var_model_id, '-exome_som_var_model_id'=>$exome_som_var_model_id, '-tumor_rna_seq_model_id'=>$tumor_rna_seq_model_id, '-normal_rna_seq_model_id'=>$normal_rna_seq_model_id);


#Create a summarized file of SNVs for: WGS, exome, and WGS+exome merged
#Grab the gene name used in the 'annotation.top' file, but grab the AA changes from the '.annotation' file
#Fix the gene name if neccessary...
#Perform druggable genes analysis on each list (filtered, kinase-only, inhibitor-only, antineoplastic-only)
$step++; print MAGENTA, "\n\nStep $step. Summarizing SNVs and Indels", RESET;
&summarizeSNVs('-data_paths'=>$data_paths, '-out_paths'=>$out_paths, '-patient_dir'=>$patient_dir, '-entrez_ensembl_data'=>$entrez_ensembl_data, '-verbose'=>$verbose);
#TODO: when merging SNVs/Indels from WGS + Exome, add a column that indicates (1|0) whether each was called by WGS or Exome, 1+1 = BOTH


#Run CNView analyses on the CNV data to identify amplified/deleted genes
$step++; print MAGENTA, "\n\nStep $step. Identifying CNV altered genes", RESET;
if ($wgs){
  my @cnv_symbol_lists = qw (Kinases CancerGeneCensusPlus DrugBankAntineoplastic DrugBankInhibitors Ensembl_v58);
  &identifyCnvGenes('-data_paths'=>$data_paths, '-out_paths'=>$out_paths, '-reference_build_name'=>$reference_build_ucsc, '-common_name'=>$common_name, '-patient_dir'=>$patient_dir, '-gene_symbol_lists_dir'=>$gene_symbol_lists_dir, '-symbol_list_names'=>\@cnv_symbol_lists, '-verbose'=>$verbose);
}


#Run RNA-seq analysis on the RNA-seq data (if available)
my $rnaseq_dir = createNewDir('-path'=>$patient_dir, '-new_dir_name'=>'rnaseq', '-silent'=>1);
if ($tumor_rnaseq){
  my $tumor_rnaseq_dir = &createNewDir('-path'=>$rnaseq_dir, '-new_dir_name'=>'tumor', '-silent'=>1);
  my $cufflinks_dir = $data_paths->{tumor_rnaseq}->{expression};
  
  #Perform the single-tumor outlier analysis
  $step++; print MAGENTA, "\n\nStep $step. Summarizing RNA-seq absolute expression values", RESET;
  &runRnaSeqAbsolute('-label'=>'tumor_rnaseq_absolute', '-cufflinks_dir'=>$cufflinks_dir, '-out_paths'=>$out_paths, '-rnaseq_dir'=>$tumor_rnaseq_dir, '-script_dir'=>$script_dir, '-verbose'=>$verbose);

  #Perform the multi-tumor differential outlier analysis

}
if ($normal_rnaseq){
  my $normal_rnaseq_dir = &createNewDir('-path'=>$rnaseq_dir, '-new_dir_name'=>'normal', '-silent'=>1);
  my $cufflinks_dir = $data_paths->{normal_rnaseq}->{expression};
  
  #Perform the single-normal outlier analysis
  $step++; print MAGENTA, "\n\nStep $step. Summarizing RNA-seq absolute expression values", RESET;
  &runRnaSeqAbsolute('-label'=>'normal_rnaseq_absolute', '-cufflinks_dir'=>$cufflinks_dir, '-out_paths'=>$out_paths, '-rnaseq_dir'=>$normal_rnaseq_dir, '-script_dir'=>$script_dir, '-verbose'=>$verbose);

  #Perform the multi-normal differential outlier analysis

}

#TODO: IF both tumor and normal RNA-seq are defined - run Cuffdiff on the comparison


#Annotate gene lists to deal with commonly asked questions like: is each gene a kinase?
#Read in file, get gene name column, fix gene name, compare to list, set answer to 1/0, overwrite old file
#Repeat this process for each gene symbol list defined
$step++; print MAGENTA, "\n\nStep $step. Annotating gene files", RESET;
&annotateGeneFiles('-gene_symbol_lists'=>$gene_symbol_lists1, '-out_paths'=>$out_paths);


#Create drugDB interaction files
$step++; print MAGENTA, "\n\nStep $step. Intersecting gene lists with druggable genes of various categories", RESET;
&drugDbIntersections('-script_dir'=>$script_dir, '-out_paths'=>$out_paths);


#For each of the following: WGS SNVs, Exome SNVs, and WGS+Exome SNVs, do the following:
#Get BAM readcounts for WGS (tumor/normal), Exome (tumor/normal), RNAseq (tumor), RNAseq (normal) - as available of course
$step++; print MAGENTA, "\n\nStep $step. Getting BAM read counts for all BAMs associated with input models (and expression values if available) - for candidate SNVs", RESET;
my @positions_files;
if ($wgs){push(@positions_files, $out_paths->{'wgs'}->{'snv'}->{path});}
if ($exome){push(@positions_files, $out_paths->{'exome'}->{'snv'}->{path});}
if ($wgs && $exome){push(@positions_files, $out_paths->{'wgs_exome'}->{'snv'}->{path});}
my $read_counts_script = "$script_dir"."snv/getBamReadCounts.pl";
my $read_counts_summary_script = "$script_dir"."snv/WGS_vs_Exome_vs_RNAseq_VAF_and_FPKM.R";
foreach my $positions_file (@positions_files){
  my $fb = &getFilePathBase('-path'=>$positions_file);
  my $output_file = $fb->{$positions_file}->{base} . ".readcounts" . $fb->{$positions_file}->{extension};
  my $output_stats_dir = $output_file . ".stats/";

  unless($wgs_som_var_model_id){$wgs_som_var_model_id=0;}
  unless($exome_som_var_model_id){$exome_som_var_model_id=0;}
  unless($tumor_rna_seq_model_id){$tumor_rna_seq_model_id=0;}
  unless($normal_rna_seq_model_id){$normal_rna_seq_model_id=0;}
  my $bam_rc_cmd = "$read_counts_script  --positions_file=$positions_file  --wgs_som_var_model_id='$wgs_som_var_model_id'  --exome_som_var_model_id='$exome_som_var_model_id'  --rna_seq_tumor_model_id='$tumor_rna_seq_model_id'  --rna_seq_normal_model_id='$normal_rna_seq_model_id'  --output_file=$output_file  --verbose=$verbose";

  #WGS_vs_Exome_vs_RNAseq_VAF_and_FPKM.R  /gscmnt/sata132/techd/mgriffit/hgs/test/ /gscmnt/sata132/techd/mgriffit/hgs/all1/snv/wgs_exome/snvs.hq.tier1.v1.annotated.compact.readcounts.tsv /gscmnt/sata132/techd/mgriffit/hgs/all1/rnaseq/tumor/absolute/isoforms_merged/isoforms.merged.fpkm.expsort.tsv
  my $rc_summary_cmd;
  if ($tumor_rna_seq_model_id){
    my $tumor_fpkm_file = $out_paths->{'tumor_rnaseq_absolute'}->{'isoforms.merged.fpkm.expsort.tsv'}->{path};
    $rc_summary_cmd = "$read_counts_summary_script $output_stats_dir $output_file $tumor_fpkm_file";
  }else{
    $rc_summary_cmd = "$read_counts_summary_script $output_stats_dir $output_file";
  }
  print RED, "\n\n$rc_summary_cmd", RESET;
  if(-e $output_file){
    if ($verbose){print YELLOW, "\n\nOutput bam read counts file already exists:\n\t$output_file", RESET;}
    if (-e $output_stats_dir && -d $output_stats_dir){
      if ($verbose){print YELLOW, "\n\nOutput read count stats dir already exists:\n\t$output_stats_dir", RESET;}
    }else{
      #Summarize the BAM readcounts results for candidate variants - produce descriptive statistics, figures etc.
      mkdir($output_stats_dir);
      system($rc_summary_cmd);
    }
  }else{
    #First get the read counts for the current file of SNVs (from WGS, Exome, or WGS+Exome
    if ($verbose){print YELLOW, "\n\n$bam_rc_cmd", RESET;}
    system($bam_rc_cmd);
    #Summarize the BAM readcounts results for candidate variants - produce descriptive statistics, figures etc.
    mkdir($output_stats_dir);
    system($rc_summary_cmd);
  }
}



#Generate a clonality plot for this patient (if WGS data is available)
if ($wgs){
  $step++; print MAGENTA, "\n\nStep $step. Creating clonality plot for $common_name", RESET;
  my $test_dir = $patient_dir . "clonality/";
  if (-e $test_dir && -d $test_dir){
    if ($verbose){print YELLOW, "\n\nClonality dir already exists - skipping", RESET;}
  }else{
    my $clonality_dir = &createNewDir('-path'=>$patient_dir, '-new_dir_name'=>'clonality', '-silent'=>1);
    my $master_clonality_cmd = "$script_dir"."snv/generateClonalityPlot.pl  --somatic_var_model_id=$wgs_som_var_model_id  --working_dir=$clonality_dir  --common_name='$common_name'  --verbose=1";
    if ($verbose){print YELLOW, "\n\n$master_clonality_cmd", RESET;}
    system($master_clonality_cmd);
  }
}

#TODO: Generate single genome (i.e. single BAM) global copy number segment plots for each BAM.  These help to identify sample swaps
#gmt copy-number plot-segments-from-bams-workflow --normal-bam=/gscmnt/gc7001/info/model_data/2880820353/build115943750/alignments/115955253.bam  --tumor-bam=/gscmnt/gc7001/info/model_data/2880820341/build115943568/alignments/115955703.bam  --output-directory=/gscmnt/sata132/techd/mgriffit/hgs/temp/seg_plots/normal_vs_primary/  --genome-build=37  --output-pdf='CNV_SingleBAMs_TumorAndNormal.pdf'


print "\n\n";

#print Dumper $out_paths;

exit();


###############################################################################################################################
#Get build directories for the three datatypes                                                                                #
###############################################################################################################################
sub getDataDirs{
  my %args = @_;
  my $wgs_som_var_model_id = $args{'-wgs_som_var_model_id'};
  my $exome_som_var_model_id = $args{'-exome_som_var_model_id'};
  my $tumor_rna_seq_model_id = $args{'-tumor_rna_seq_model_id'};
  my $normal_rna_seq_model_id = $args{'-normal_rna_seq_model_id'};

  my %data_paths;
  
  my ($wgs_som_var_datadir, $exome_som_var_datadir, $tumor_rna_seq_datadir, $normal_rna_seq_datadir) = ('', '', '', '');
  if ($wgs_som_var_model_id){
    my $wgs_som_var_model = Genome::Model->get($wgs_som_var_model_id);
    if ($wgs_som_var_model){
      my $wgs_som_var_build = $wgs_som_var_model->last_succeeded_build;
      if ($wgs_som_var_build){
        #... /genome/lib/perl/Genome/Model/Build/SomaticVariation.pm
        $data_paths{wgs}{root} =  $wgs_som_var_build->data_directory ."/";
        $data_paths{wgs}{normal_bam} = $wgs_som_var_build->normal_bam;
        $data_paths{wgs}{tumor_bam} = $wgs_som_var_build->tumor_bam;
      }else{
        print RED, "\n\nA WGS model ID was specified, but a successful build could not be found!\n\n", RESET;
        exit();
      }
    }else{
      print RED, "\n\nA WGS model ID was specified, but it could not be found!\n\n", RESET;
      exit();
    }
  }
  if ($exome_som_var_model_id){
    my $exome_som_var_model = Genome::Model->get($exome_som_var_model_id);
    if ($exome_som_var_model){
      my $exome_som_var_build = $exome_som_var_model->last_succeeded_build;
      if ($exome_som_var_build){
        $data_paths{exome}{root} = $exome_som_var_build->data_directory ."/";
        $data_paths{exome}{normal_bam} = $exome_som_var_build->normal_bam;
        $data_paths{exome}{tumor_bam} = $exome_som_var_build->tumor_bam;
      }else{
        print RED, "\n\nAn exome model ID was specified, but a successful build could not be found!\n\n", RESET;
        exit();
      }
    }else{
      print RED, "\n\nAn exome model ID was specified, but it could not be found!\n\n", RESET;
      exit();
    }
  }
  if ($tumor_rna_seq_model_id){
    my $rna_seq_model = Genome::Model->get($tumor_rna_seq_model_id);
      if ($rna_seq_model){
      my $rna_seq_build = $rna_seq_model->last_succeeded_build;
      if ($rna_seq_build){
        $data_paths{tumor_rnaseq}{root} = $rna_seq_build->data_directory ."/";
        my $alignment_result = $rna_seq_build->alignment_result;
        $data_paths{tumor_rnaseq}{bam} = $alignment_result->bam_file;
      }else{
        print RED, "\n\nA tumor RNA-seq model ID was specified, but a successful build could not be found!\n\n", RESET;
        exit();
      }
    }else{
      print RED, "\n\nA tumor RNA-seq model ID was specified, but it could not be found!\n\n", RESET;
      exit();
    }
  }

  if ($normal_rna_seq_model_id){
    my $rna_seq_model = Genome::Model->get($normal_rna_seq_model_id);
      if ($rna_seq_model){
      my $rna_seq_build = $rna_seq_model->last_succeeded_build;
      if ($rna_seq_build){
        $data_paths{normal_rnaseq}{root} = $rna_seq_build->data_directory ."/";
        my $alignment_result = $rna_seq_build->alignment_result;
        $data_paths{normal_rnaseq}{bam} = $alignment_result->bam_file;
      }else{
        print RED, "\n\nA normal RNA-seq model ID was specified, but a successful build could not be found!\n\n", RESET;
        exit();
      }
    }else{
      print RED, "\n\nA normal RNA-seq model ID was specified, but it could not be found!\n\n", RESET;
      exit();
    }
  }

  my @dt = qw(wgs exome);
  foreach my $dt (@dt){
    if ($data_paths{$dt}{root}){
      my $root = $data_paths{$dt}{root};
      $data_paths{$dt}{effects} = $root."effects/";
      $data_paths{$dt}{logs} = $root."logs/";
      $data_paths{$dt}{loh} = $root."loh/";
      $data_paths{$dt}{novel} = $root."novel/";
      $data_paths{$dt}{reports} = $root."reports/";
      $data_paths{$dt}{variants} = $root."variants/";
    }
  }

  if ($data_paths{tumor_rnaseq}{root}){
    my $root = $data_paths{tumor_rnaseq}{root};
    $data_paths{tumor_rnaseq}{alignments} = $root."alignments/";
    $data_paths{tumor_rnaseq}{coverage} = $root."coverage/";
    $data_paths{tumor_rnaseq}{expression} = $root."expression/";
    $data_paths{tumor_rnaseq}{logs} = $root."logs/";
    $data_paths{tumor_rnaseq}{reports} = $root."reports/";
  }

  if ($data_paths{normal_rnaseq}{root}){
    my $root = $data_paths{normal_rnaseq}{root};
    $data_paths{normal_rnaseq}{alignments} = $root."alignments/";
    $data_paths{normal_rnaseq}{coverage} = $root."coverage/";
    $data_paths{normal_rnaseq}{expression} = $root."expression/";
    $data_paths{normal_rnaseq}{logs} = $root."logs/";
    $data_paths{normal_rnaseq}{reports} = $root."reports/";
  }

  #print Dumper %data_paths;

  return(\%data_paths);
}


###################################################################################################################
#Summarize SNVs/Indels                                                                                            #
###################################################################################################################
sub summarizeSNVs{
  my %args = @_;
  my $data_paths = $args{'-data_paths'};
  my $out_paths = $args{'-out_paths'};
  my $patient_dir = $args{'-patient_dir'};
  my $entrez_ensembl_data = $args{'-entrez_ensembl_data'};
  my $verbose = $args{'-verbose'};

  #Create SNV dirs: 'snv', 'snv/wgs/', 'snv/exome/', 'snv/wgs_exome/'
  my $snv_dir = &createNewDir('-path'=>$patient_dir, '-new_dir_name'=>'snv', '-silent'=>1);
  my $snv_wgs_dir = &createNewDir('-path'=>$snv_dir, '-new_dir_name'=>'wgs', '-silent'=>1);
  my $snv_exome_dir = &createNewDir('-path'=>$snv_dir, '-new_dir_name'=>'exome', '-silent'=>1);
  my $snv_wgs_exome_dir = &createNewDir('-path'=>$snv_dir, '-new_dir_name'=>'wgs_exome', '-silent'=>1);

  #Create INDEL dirs
  my $indel_dir = &createNewDir('-path'=>$patient_dir, '-new_dir_name'=>'indel', '-silent'=>1);
  my $indel_wgs_dir = &createNewDir('-path'=>$indel_dir, '-new_dir_name'=>'wgs', '-silent'=>1);
  my $indel_exome_dir = &createNewDir('-path'=>$indel_dir, '-new_dir_name'=>'exome', '-silent'=>1);
  my $indel_wgs_exome_dir = &createNewDir('-path'=>$indel_dir, '-new_dir_name'=>'wgs_exome', '-silent'=>1);

  #Define variant effect type filters
  my $snv_filter = "missense|nonsense|splice_site";
  my $indel_filter = "in_frame_del|in_frame_ins|frame_shift_del|frame_shift_ins|splice_site_ins|splice_site_del";

  #Define the dataset: WGS SNV, WGS indel, Exome SNV, Exome indel
  my %dataset;
  if ($wgs){
    my $effects_dir = $data_paths->{'wgs'}->{'effects'};
    $dataset{'1'}{data_type} = "wgs";
    $dataset{'1'}{var_type} = "snv";
    $dataset{'1'}{effects_dir} = $effects_dir;
    $dataset{'1'}{t1_hq_annotated} = "snvs.hq.tier1.v1.annotated";
    $dataset{'1'}{t1_hq_annotated_top} = "snvs.hq.tier1.v1.annotated.top";
    $dataset{'1'}{compact_file} = "$snv_wgs_dir"."snvs.hq.tier1.v1.annotated.compact.tsv";
    $dataset{'1'}{aa_effect_filter} = $snv_filter;
    $dataset{'1'}{target_dir} = $snv_wgs_dir;

    $dataset{'2'}{data_type} = "wgs";
    $dataset{'2'}{var_type} = "indel";
    $dataset{'2'}{effects_dir} = $effects_dir;
    $dataset{'2'}{t1_hq_annotated} = "indels.hq.tier1.v1.annotated";
    $dataset{'2'}{t1_hq_annotated_top} = "indels.hq.tier1.v1.annotated.top";
    $dataset{'2'}{compact_file} = "$indel_wgs_dir"."indels.hq.tier1.v1.annotated.compact.tsv";
    $dataset{'2'}{aa_effect_filter} = $indel_filter;
    $dataset{'2'}{target_dir} = $indel_wgs_dir;
  }
  if ($exome){
    my $effects_dir = $data_paths->{'exome'}->{'effects'};
    $dataset{'3'}{data_type} = "exome";
    $dataset{'3'}{var_type} = "snv";
    $dataset{'3'}{effects_dir} = $effects_dir;
    $dataset{'3'}{t1_hq_annotated} = "snvs.hq.tier1.v1.annotated";
    $dataset{'3'}{t1_hq_annotated_top} = "snvs.hq.tier1.v1.annotated.top";
    $dataset{'3'}{compact_file} = "$snv_exome_dir"."snvs.hq.tier1.v1.annotated.compact.tsv";
    $dataset{'3'}{aa_effect_filter} = $snv_filter;
    $dataset{'3'}{target_dir} = $snv_exome_dir;

    $dataset{'4'}{data_type} = "exome";
    $dataset{'4'}{var_type} = "indel";
    $dataset{'4'}{effects_dir} = $effects_dir;
    $dataset{'4'}{t1_hq_annotated} = "indels.hq.tier1.v1.annotated";
    $dataset{'4'}{t1_hq_annotated_top} = "indels.hq.tier1.v1.annotated.top";
    $dataset{'4'}{compact_file} = "$indel_exome_dir"."indels.hq.tier1.v1.annotated.compact.tsv";
    $dataset{'4'}{aa_effect_filter} = $indel_filter;
    $dataset{'4'}{target_dir} = $indel_exome_dir;
  }

  my %data_merge;
  foreach my $ds (sort {$a <=> $b} keys %dataset){
    my %data_out;

    #Make a copy of the high quality .annotated and .annotated.top files
    my $data_type = $dataset{$ds}{data_type};
    my $var_type = $dataset{$ds}{var_type};
    my $effects_dir = $dataset{$ds}{effects_dir};
    my $t1_hq_annotated = $dataset{$ds}{t1_hq_annotated};
    my $t1_hq_annotated_top = $dataset{$ds}{t1_hq_annotated_top};
    my $compact_file = $dataset{$ds}{compact_file};
    my $aa_effect_filter = $dataset{$ds}{aa_effect_filter};
    my $target_dir = $dataset{$ds}{target_dir};

    #system ("cp $t1_hq_annotated $t1_hq_annotated_top $target_dir");
    system ("cp $effects_dir$t1_hq_annotated $target_dir$t1_hq_annotated".".tsv");
    system ("cp $effects_dir$t1_hq_annotated_top $target_dir$t1_hq_annotated_top".".tsv");

    #Define headers in a variant file
    my @input_headers = qw (chr start stop ref_base var_base var_type gene_name transcript_id species transcript_source transcript_version strand transcript_status var_effect_type coding_pos aa_change score domains1 domains2 unk_1 unk_2);
    
    #Get AA changes from full .annotated file
    my %aa_changes;
    my $reader = Genome::Utility::IO::SeparatedValueReader->create(
      headers => \@input_headers,
      input => "$target_dir$t1_hq_annotated".".tsv",
      separator => "\t",
    );
    while (my $data = $reader->next) {
      my $coord = $data->{chr} .':'. $data->{start} .'-'. $data->{stop};
      $data->{coord} = $coord;
      unless ($data->{var_effect_type} =~ /$aa_effect_filter/){
        next();
      }
      $aa_changes{$coord}{$data->{aa_change}}=1;
    }

    #Get compact SNV info from the '.top' file but grab the complete list of AA changes from the '.annotated' file
    $reader = Genome::Utility::IO::SeparatedValueReader->create(
      headers => \@input_headers,
      input => "$target_dir$t1_hq_annotated_top".".tsv",
      separator => "\t",
    );

    while (my $data = $reader->next){
      my $coord = $data->{chr} .':'. $data->{start} .'-'. $data->{stop};
      unless ($data->{var_effect_type} =~ /$aa_effect_filter/){
        next();
      }
      my %aa = %{$aa_changes{$coord}};
      my $aa_string = join(",", sort keys %aa);
      $data_out{$coord}{gene_name} = $data->{gene_name};
      $data_merge{$var_type}{$coord}{gene_name} = $data->{gene_name};
      $data_out{$coord}{aa_changes} = $aa_string;
      $data_merge{$var_type}{$coord}{aa_changes} = $aa_string;
      $data_out{$coord}{ref_base} = $data->{ref_base};
      $data_merge{$var_type}{$coord}{ref_base} = $data->{ref_base};
      $data_out{$coord}{var_base} = $data->{var_base};
      $data_merge{$var_type}{$coord}{var_base} = $data->{var_base};

      #Attempt to fix the gene name:
      my $fixed_gene_name = &fixGeneName('-gene'=>$data->{gene_name}, '-entrez_ensembl_data'=>$entrez_ensembl_data, '-verbose'=>0);
      $data_out{$coord}{mapped_gene_name} = $fixed_gene_name;
      $data_merge{$var_type}{$coord}{mapped_gene_name} = $fixed_gene_name;

    }

    #Print out the resulting list, sorting on fixed gene name
    open (OUT, ">$compact_file") || die "\n\nCould not open output file: $compact_file\n\n";

    print OUT "coord\tgene_name\tmapped_gene_name\taa_changes\tref_base\tvar_base\n";
    foreach my $coord (sort {$data_out{$a}->{mapped_gene_name} cmp $data_out{$b}->{mapped_gene_name}} keys %data_out){
      print OUT "$coord\t$data_out{$coord}{gene_name}\t$data_out{$coord}{mapped_gene_name}\t$data_out{$coord}{aa_changes}\t$data_out{$coord}{ref_base}\t$data_out{$coord}{var_base}\n";
    }
    close(OUT);

    #Store the path for this output file
    $out_paths->{$data_type}->{$var_type}->{path} = $compact_file;

    #print Dumper %data_out;
  }

  #If both WGS and Exome data were present, print out a data merge for SNVs and Indels
  if ($wgs && $exome){
    my $snv_merge_file = "$snv_wgs_exome_dir"."snvs.hq.tier1.v1.annotated.compact.tsv";
    my $indel_merge_file = "$indel_wgs_exome_dir"."indels.hq.tier1.v1.annotated.compact.tsv";

    open (OUT, ">$snv_merge_file") || die "\n\nCould not open output file: $snv_merge_file\n\n";
    print OUT "coord\tgene_name\tmapped_gene_name\taa_changes\tref_base\tvar_base\n";
    my %data_out = %{$data_merge{'snv'}};
    foreach my $coord (sort {$data_out{$a}->{mapped_gene_name} cmp $data_out{$b}->{mapped_gene_name}} keys %data_out){
      print OUT "$coord\t$data_out{$coord}{gene_name}\t$data_out{$coord}{mapped_gene_name}\t$data_out{$coord}{aa_changes}\t$data_out{$coord}{ref_base}\t$data_out{$coord}{var_base}\n";
    }
    close(OUT);
    $out_paths->{'wgs_exome'}->{'snv'}->{path} = $snv_merge_file;

    open (OUT, ">$indel_merge_file") || die "\n\nCould not open output file: $indel_merge_file\n\n";
    print OUT "coord\tgene_name\tmapped_gene_name\taa_changes\tref_base\tvar_base\n";
    %data_out = %{$data_merge{'indel'}};
    foreach my $coord (sort {$data_out{$a}->{mapped_gene_name} cmp $data_out{$b}->{mapped_gene_name}} keys %data_out){
      print OUT "$coord\t$data_out{$coord}{gene_name}\t$data_out{$coord}{mapped_gene_name}\t$data_out{$coord}{aa_changes}\t$data_out{$coord}{ref_base}\t$data_out{$coord}{var_base}\n";
    }
    close(OUT);
    $out_paths->{'wgs_exome'}->{'indel'}->{path} = $indel_merge_file;
  }

  return();
}


###################################################################################################################################
#Run CNView analyses on the CNV data to identify amplified/deleted genes                                                          #
###################################################################################################################################
sub identifyCnvGenes{
  my %args = @_;
  my $data_paths = $args{'-data_paths'};
  my $out_paths = $args{'-out_paths'};
  my $common_name = $args{'-common_name'};
  my $reference_build_name = $args{'-reference_build_name'};
  my $patient_dir = $args{'-patient_dir'}; 
  my $gene_symbol_lists_dir = $args{'-gene_symbol_lists_dir'};
  my @symbol_list_names = @{$args{'-symbol_list_names'}}; 
  my $verbose = $args{'-verbose'};

  my $variants_dir = $data_paths->{'wgs'}->{'variants'};
  my $cnv_data_file = $variants_dir."cnvs.hq";

  #Create main CNV dir: 'cnv'
  my $cnv_dir = &createNewDir('-path'=>$patient_dir, '-new_dir_name'=>'cnv', '-silent'=>1);
  my $cnview_script = "$script_dir"."cnv/CNView.pl";

  #For each list of gene symbols, run the CNView analysis
  foreach my $symbol_list_name (@symbol_list_names){
    my $gene_targets_file = "$gene_symbol_lists_dir"."$symbol_list_name".".txt";

    #Only run CNView if the directory is not already present
    my $new_dir = "$cnv_dir"."CNView_"."$symbol_list_name"."/";
    unless (-e $new_dir && -d $new_dir){
      my $cnview_cmd = "$cnview_script  --reference_build=$reference_build_name  --cnv_file=$cnv_data_file  --working_dir=$cnv_dir  --sample_name=$common_name  --gene_targets_file=$gene_targets_file  --name='$symbol_list_name'  --force=1";
      #print "\n\n$cnview_cmd";
      system ($cnview_cmd);
      #  CNView.pl  --reference_build=hg19  --cnv_file=/gscmnt/ams1184/info/model_data/2875816457/build111674790/variants/cnvs.hq  --working_dir=/gscmnt/sata132/techd/mgriffit/hg1/cnvs/  --sample_name=hg1  --gene_targets_file=/gscmnt/sata132/techd/mgriffit/reference_annotations/hg19/gene_symbol_lists/CancerGeneCensusPlus.txt  --name='CancerGeneCensusPlus'  
    }

    #Store the gene amplification/deletion results files for the full Ensembl gene list so that these file can be annotated
    if ($symbol_list_name =~ /Ensembl/){
      #Copy these files to the top CNV dir
      my $cnv_path1 = "$new_dir"."CNView_"."$symbol_list_name".".tsv";
      my $cnv_path2 = "$cnv_dir"."cnv."."$symbol_list_name".".tsv";
      system("cp $cnv_path1 $cnv_path2");
      my $cnv_amp_path1 = "$new_dir"."CNView_"."$symbol_list_name".".amp.tsv";
      my $cnv_amp_path2 = "$cnv_dir"."cnv."."$symbol_list_name".".amp.tsv";
      system("cp $cnv_amp_path1 $cnv_amp_path2");
      my $cnv_del_path1 = "$new_dir"."CNView_"."$symbol_list_name".".del.tsv";
      my $cnv_del_path2 = "$cnv_dir"."cnv."."$symbol_list_name".".del.tsv";
      system("cp $cnv_del_path1 $cnv_del_path2");
      my $cnv_ampdel_path1 = "$new_dir"."CNView_"."$symbol_list_name".".ampdel.tsv";
      my $cnv_ampdel_path2 = "$cnv_dir"."cnv."."$symbol_list_name".".ampdel.tsv";
      system("cp $cnv_ampdel_path1 $cnv_ampdel_path2");
      $out_paths->{'wgs'}->{'cnv'}->{'path'} = $cnv_path2;
      $out_paths->{'wgs'}->{'cnv_amp'}->{'path'} = $cnv_amp_path2;
      $out_paths->{'wgs'}->{'cnv_del'}->{'path'} = $cnv_del_path2;
      $out_paths->{'wgs'}->{'cnv_ampdel'}->{'path'} = $cnv_ampdel_path2;
    }
  }
  return();
}


###################################################################################################################################
#Run RNAseq absolute analysis to identify highly expressed genes                                                                  #
###################################################################################################################################
sub runRnaSeqAbsolute{
  my %args = @_;
  my $label = $args{'-label'};
  my $cufflinks_dir = $args{'-cufflinks_dir'};
  my $out_paths = $args{'-out_paths'};
  my $rnaseq_dir = $args{'-rnaseq_dir'};
  my $script_dir = $args{'-script_dir'};
  my $verbose = $args{'-verbose'};
  #Skip this analysis if the directory already exists
  my $test_dir = $rnaseq_dir . "absolute/";
  unless (-e $test_dir && -d $test_dir){
    my $absolute_rnaseq_dir = &createNewDir('-path'=>$rnaseq_dir, '-new_dir_name'=>'absolute', '-silent'=>1);
    my $outliers_cmd = "$script_dir"."rnaseq/outlierGenesAbsolute.pl  --cufflinks_dir=$cufflinks_dir  --working_dir=$absolute_rnaseq_dir  --verbose=$verbose";
    if ($verbose){print YELLOW, "\n\n$outliers_cmd\n\n", RESET;}
    system($outliers_cmd);
  }
  #Store the file paths for later processing
  my $absolute_rnaseq_dir = "$rnaseq_dir"."absolute/";
  my @subdirs = qw (genes isoforms isoforms_merged);
  foreach my $subdir (@subdirs){
    my $subdir_path = "$absolute_rnaseq_dir"."$subdir/";
    opendir(DIR, $subdir_path);
    my @files = readdir(DIR);
    closedir(DIR);
    foreach my $file (@files){
      #Only store .tsv files
      if ($file =~ /\.tsv$/){
        #Store the files to be annotated later:
        $out_paths->{$label}->{$file}->{'path'} = $subdir_path.$file;
      }
    }
  }
  return();
}


###################################################################################################################################
#Annotate gene lists to deal with commonly asked questions like: is each gene a kinase?                                           #
#Read in file, get gene name column, fix gene name, compare to list, set answer to 1/0, overwrite old file                        #
#Repeat this process for each gene symbol list defined                                                                            #
###################################################################################################################################
sub annotateGeneFiles{
  my %args = @_;
  my $gene_symbol_lists = $args{'-gene_symbol_lists'};
  my $out_paths = $args{'-out_paths'};

  foreach my $type (keys %{$out_paths}){
    my $sub_types = $out_paths->{$type};
    foreach my $sub_type (keys %{$sub_types}){
      #Store the file input data for this file
      my $path = $sub_types->{$sub_type}->{'path'};
      my $new_path = $path.".tmp";
      open (INDATA, "$path") || die "\n\nCould not open input datafile: $path\n\n";
      my %data;
      my %cols;
      my $header = 1;
      my $header_line = '';
      my $l = 0;
      while(<INDATA>){
        $l++;
        chomp($_);
        my $record = $_;
        my @line = split("\t", $_);
        if ($header == 1){
          my $c = 0;
          $header_line = $_;
          foreach my $colname (@line){
            $cols{$colname}{position} = $c;
            $c++;
          }
          $header = 0;
          unless ($cols{'mapped_gene_name'}){
            print RED, "\n\nFile has no 'mapped_gene_name' column: $path\n\n", RESET;
            exit();
          }
          next();
        }
        $data{$l}{record} = $record;
        $data{$l}{gene_name} = $line[$cols{'mapped_gene_name'}{position}];
      }
      close(INDATA);

      #Figure out the gene matches to the gene symbol lists
      #Test each gene name in this column against those in the list and add a column with the match status (i.e. is is a kinase, cancer gene, etc.)
      foreach my $l (keys %data){
        my $gene_name = $data{$l}{gene_name};
        foreach my $gene_symbol_type (keys %{$gene_symbol_lists}){
          my $gene_symbols = $gene_symbol_lists->{$gene_symbol_type}->{symbols};
          if ($gene_symbols->{$gene_name}){
            $data{$l}{$gene_symbol_type} = 1;
          }else{
            $data{$l}{$gene_symbol_type} = 0;
          }
        }
      }
      #Print out a new file contain the extra columns
      open (OUTDATA, ">$new_path") || die "\n\nCould not open output datafile: $new_path\n\n";
      my @gene_symbol_list_names = sort {$gene_symbol_lists->{$a}->{order} <=> $gene_symbol_lists->{$b}->{order}} keys %{$gene_symbol_lists};
      my $gene_symbol_list_name_string = join("\t", @gene_symbol_list_names);
      print OUTDATA "$header_line\t$gene_symbol_list_name_string\n";
      foreach my $l (sort {$a <=> $b} keys %data){
        my @tmp;
        foreach my $gene_symbol_list_name (@gene_symbol_list_names){
          push (@tmp, $data{$l}{$gene_symbol_list_name});
        }
        my $new_cols_string = join("\t", @tmp);
        print OUTDATA "$data{$l}{record}\t$new_cols_string\n";
      }
      close(OUTDATA);

      #Replace the original file with the new file
      my $mv_cmd = "mv $new_path $path";
      system ($mv_cmd);

    }
  }
  return();
}


###################################################################################################################################
#Create drugDB interaction files                                                                                                  #
###################################################################################################################################
sub drugDbIntersections{
  my %args = @_;
  my $script_dir = $args{'-script_dir'};
  my $out_paths = $args{'-out_paths'};

  foreach my $type (keys %{$out_paths}){
    my $sub_types = $out_paths->{$type};
    foreach my $sub_type (keys %{$sub_types}){
      #Store the file input data for this file
      my $path = $sub_types->{$sub_type}->{'path'};
      my $name_col = &getColumnPosition('-path'=>$path, '-column_name'=>'mapped_gene_name');
      my $drugdb_script = "$script_dir"."summary/identifyDruggableGenes.pl";

      #Get file path with the file extension removed:
      my $fb = &getFilePathBase('-path'=>$path);

      #Default filter
      my $out1 = $fb->{$path}->{base} . ".dgidb.default" . $fb->{$path}->{extension};
      my $cmd1 = "$drugdb_script --candidates_file=$path  --name_col_1=$name_col  --interactions_file=/gscmnt/sata132/techd/mgriffit/DruggableGenes/KnownDruggable/DrugBank/query_files/DrugBank_WashU_INTERACTIONS.filtered.3.tsv  --name_col_2=12 > $out1";
      unless (-e $out1){
        system ("$cmd1");
      }

      #Anti-neoplastic only
      my $out2 = $fb->{$path}->{base} . ".dgidb.antineo" . $fb->{$path}->{extension};
      my $cmd2 = "$drugdb_script --candidates_file=$path  --name_col_1=$name_col  --interactions_file=/gscmnt/sata132/techd/mgriffit/DruggableGenes/KnownDruggable/DrugBank/query_files/DrugBank_WashU_INTERACTIONS.filtered.4.tsv  --name_col_2=12 > $out2";
      unless (-e $out2){
        system ("$cmd2");
      }

      #Inhibitor only
      my $out3 = $fb->{$path}->{base} . ".dgidb.inhibitor" . $fb->{$path}->{extension};
      my $cmd3 = "$drugdb_script --candidates_file=$path  --name_col_1=$name_col  --interactions_file=/gscmnt/sata132/techd/mgriffit/DruggableGenes/KnownDruggable/DrugBank/query_files/DrugBank_WashU_INTERACTIONS.filtered.5.tsv  --name_col_2=12 > $out3";
      unless (-e $out3){
        system ("$cmd3");
      }

      #Kinases only
      my $out4 = $fb->{$path}->{base} . ".dgidb.kinase" . $fb->{$path}->{extension};
      my $cmd4 = "$drugdb_script --candidates_file=$path  --name_col_1=$name_col  --interactions_file=/gscmnt/sata132/techd/mgriffit/DruggableGenes/KnownDruggable/DrugBank/query_files/DrugBank_WashU_INTERACTIONS.filtered.6.tsv  --name_col_2=12 > $out4";
      unless (-e $out4){
        system ("$cmd4");
      }
    }
  }
  return();
}





