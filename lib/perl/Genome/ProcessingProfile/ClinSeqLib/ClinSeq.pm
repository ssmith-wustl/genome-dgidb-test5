=head1 NAME

ClinSeq.pm - library modules that contains generic utilities

=head1 SYNOPSIS

use ClinSeq qw(:all);

=head2 NOTE

currently located in 'clinseq'

=head2 RECENT CHANGES

None.  Last modified 6 Oct. 2011

=head1 DESCRIPTION

Generic utility functions

=head1 EXAMPLES

use lib './';

use ClinSeq qw(:all);

=head1 SEE ALSO

None

=head1 BUGS

Contact author via email

=head1 AUTHOR

Written by Malachi Griffith (mgriffit@genome.wustl.edu)

=head1 AFFLIATIONS

Malachi Griffith is supervised by Elaine Mardis

The Genome Institute, Washington University School of Medicine

=head1 SUBROUTINES

=cut

#Copyright 2011 Malachi Griffith

package ClinSeq;
require Exporter;

@ISA = qw( Exporter );
@EXPORT = qw();

@EXPORT_OK = qw(
                &createNewDir &checkDir &commify &memoryUsage &loadEntrezEnsemblData &mapGeneName &fixGeneName &importIdeogramData &getCytoband &getColumnPosition
               );

%EXPORT_TAGS = (
                all => [qw(&createNewDir &checkDir &commify &memoryUsage &loadEntrezEnsemblData &mapGeneName &fixGeneName &importIdeogramData &getCytoband &getColumnPosition)]
               );

use strict;
use warnings;
use Data::Dumper;
use Term::ANSIColor qw(:constants);


=head2 createNewDir

=over 3

=item Function:

Create a new directory cleanly in the specified location - Prompt user for confirmation

=item Return:

Full path to new directory

=item Args:

'-path' - Full path to new directoy

'-new_dir_name' - Name of new directory

'-force' - Clobber existing data

'-silent' - No user prompts, will make dir if it does not exist, otherwise do nothing

=item Example(s):

my $fasta_dir = &createNewDir('-path'=>$temp_dir, '-new_dir_name'=>"ensembl_genes_fasta");

=back

=cut

###############################################################################################################
#Create a new directory in a specified location                                                               #
###############################################################################################################
sub createNewDir{
  my %args = @_;
  my $base_path = $args{'-path'};
  my $name = $args{'-new_dir_name'};
  my $force = $args{'-force'};
  my $silent = $args{'-silent'};

  #Now make sure the desired new dir does not already exist
  unless ($base_path =~ /.*\/$/){
    $base_path = "$base_path"."/";
  }

  #First make sure the specified base path exists and is a directory
  unless (-e $base_path && -d $base_path){
    print RED, "\nSpecified working directory: $base_path does not appear valid! Create a working directory before proceeding\n\n", RESET;
    exit();
  }

  unless ($name =~ /.*\/$/){
    $name = "$name"."/";
  }

  my $new_path = "$base_path"."$name";

  if (-e $new_path && -d $new_path){

    if ($force){
      #If this directory already exists, and the -force option was provide, delete this directory and start it cleanly
      if ($force eq "yes"){
	print YELLOW, "\nForcing clean creation of $new_path\n\n", RESET;
	my $command = "rm -r $new_path";
	system ($command);
	mkdir($new_path);
      }else{
	print RED, "\nThe '-force' option provided to utility.pm was not understood!!", RESET;
	exit();
      }

    }elsif($silent){
      #Do nothing.
      
    }else{

      #If this directory already exists, ask the user if they wish to erase it and start clean
      print YELLOW, "\nNew dir: $new_path already exists.\n\tDo you wish to delete it and create it cleanly (y/n)? ", RESET;
      my $answer = <>;

      chomp($answer);

      if ($answer =~ /^y$/i | $answer =~ /^yes$/i){
	my $command = "rm -r $new_path";
	system ($command);
	mkdir($new_path);
      }else{
	print YELLOW, "\nUsing existing directory, some files may be over-written and others that are unrelated to the current analysis may remain!\n", RESET;
      }
    }

  }else{
    mkdir($new_path)
  }
  return($new_path);
}


=head2 checkDir

=over 3

=item Function:

Check validity of a directory and empty if the user desires - Prompt user for confirmation

=item Return:

Path to clean,valid directory

=item Args:

'-dir' - Full path to directory to be checked

'-clear' - 'yes/no' option to clear the specified directory of files

'-force' - 'yes/no' force clear without user prompt

=item Example(s):

my $working_dir = &checkDir('-dir'=>$working_dir, '-clear'=>"yes");

=back

=cut


#############################################################################################################################
#Check dir
#############################################################################################################################
sub checkDir{
  my %args = @_;
  my $dir = $args{'-dir'};
  my $clear = $args{'-clear'};
  my $force = $args{'-force'};
  my $recursive = $args{'-recursive'};

  unless ($dir =~ /\/$/){
    $dir = "$dir"."/";
  }
  unless (-e $dir && -d $dir){
    print RED, "\nDirectory: $dir does not appear to be valid!\n\n", RESET;
    exit();
  }

  unless ($force){
    $force = "no";
  }
  unless ($clear){
    $clear = "no";
  }
  unless ($recursive){
    $recursive = "no";
  }

  #Clean up the working directory
  opendir(DIRHANDLE, "$dir") || die "\nCannot open directory: $dir\n\n";
  my @temp = readdir(DIRHANDLE);
  closedir(DIRHANDLE);

  if ($clear =~ /y|yes/i){

    if ($force =~ /y|yes/i){
      if ($recursive =~ /y|yes/i){
        my $files_present = scalar(@temp) - 2;
        my $clean_dir_cmd = "rm -fr $dir"."*";
        print YELLOW, "\n\n$clean_dir_cmd\n\n", RESET;
        system($clean_dir_cmd);
      }else{
        my $files_present = scalar(@temp) - 2;
        my $clean_dir_cmd = "rm -f $dir"."*";
        print YELLOW, "\n\n$clean_dir_cmd\n\n", RESET;
        system($clean_dir_cmd);
      }
    }else{

      my $files_present = scalar(@temp) - 2;
      my $clean_dir_cmd = "rm $dir"."*";
      if ($recursive =~ /y|yes/i){
        $clean_dir_cmd = "rm -fr $dir"."*";
      }

      unless ($files_present == 0){
	print YELLOW, "\nFound $files_present files in the specified directory ($dir)\nThis directory will be cleaned with the command:\n\t$clean_dir_cmd\n\nProceed (y/n)? ", RESET;
	my $answer = <>;
	chomp($answer);
	if ($answer =~ /y|yes/i){
          if ($recursive =~ /y|yes/i){
            system($clean_dir_cmd);
          }else{
	    system($clean_dir_cmd);
          }
	}else{
	  print YELLOW, "\nContinuing and leaving files in place then ...\n\n", RESET;
	}
      }
    }
  }
  return($dir);
}


#######################################################################################################################################################################
#Load Entrez Data from flatfiles                                                                                                                                      #
#######################################################################################################################################################################
sub loadEntrezEnsemblData{
  my %args = @_;
  my $entrez_dir = $args{'-entrez_dir'};
  my $ensembl_dir = $args{'-ensembl_dir'};
  my %edata;

  #Check input dirs
  unless (-e $entrez_dir && -d $entrez_dir){
    print RED, "\n\nEntrez dir not valid: $entrez_dir\n\n", RESET;
    exit();
  }
  unless ($entrez_dir =~ /\/$/){
    $entrez_dir .= "/";
  }
  unless (-e $ensembl_dir && -d $ensembl_dir){
    print RED, "\n\nEnsembl dir not valid: $ensembl_dir\n\n", RESET;
    exit();
  }
  unless ($ensembl_dir =~ /\/$/){
    $ensembl_dir .= "/";
  }

  #Load data from Ensembl files
  my %entrez_map;      #Entrez_id          -> symbol, synonyms
  my %ensembl_map;     #Ensembl_id         -> entrez_id(s) - from Entrez
  my %ensembl_map2;    #Ensembl_id         -> symbol(s) - from Ensembl
  my %symbols_map;     #Symbols            -> entrez_id(s)
  my %synonyms_map;    #Synonyms           -> entrez_id(s)
  my %p_acc_map;       #Protein accessions -> entrez_id(s)
  my %g_acc_map;       #Genomic accessions -> entrez_id(s)

  my $gene2accession_file = "$entrez_dir"."gene2accession.human";
  my $gene_info_file = "$entrez_dir"."gene_info.human";
  open (GENE, "$gene_info_file") || die "\n\nCould not open gene_info file: $gene_info_file\n\n";
  while(<GENE>){
    chomp($_);
    if ($_ =~ /^\#/){
      next();
    }
    my @line = split("\t", $_);
    my $tax_id = uc($line[0]);
    #Skip all non-human records
    unless ($tax_id eq "9606"){
      next();
    }
    my $entrez_id = uc($line[1]);
    my $symbol = uc($line[2]);
    my $synonyms = uc($line[4]);
    my $ext_ids = uc($line[5]);

    #Get synonyms for each gene and divide each into a unique hash
    if ($synonyms eq "-"){
      $synonyms = "na";
    }
    my @synonyms_array = split("\\|", $synonyms);
    my %synonyms_hash;   
    foreach my $syn (@synonyms_array){
      $synonyms_hash{$syn} = 1;
    }

    #Parse the external IDs field for Ensembl gene IDs (Other possibilites include HGNC, MIM, HPRD)
    my %ensembl_hash;
    my @ext_ids_array = split("\\|", $ext_ids);
    $entrez_map{$entrez_id}{ensembl_id} = "na";
    foreach my $ext_string (@ext_ids_array){
      if ($ext_string =~ /ENSEMBL/i){
        if ($ext_string =~ /ENSEMBL\:(\w+)/){
          $entrez_map{$entrez_id}{ensembl_id} = $1;
          $ensembl_hash{$1} = 1;
        }else{
          print RED, "\n\nFormat of Ensembl field not understood: $ext_string\n\n", RESET;
          exit();
        }   
      }else{
        next();
      }
    }

    #Store entrez info keyed on entrez id
    #print "\n$entrez_id\t$symbol\t@synonyms_array";
    $entrez_map{$entrez_id}{symbol} = $symbol;
    $entrez_map{$entrez_id}{synonyms_string} = $synonyms;
    $entrez_map{$entrez_id}{synonyms_array} = \@synonyms_array;
    $entrez_map{$entrez_id}{synonyms_hash} = \%synonyms_hash;

    #Store entrez info keyed on symbol
    #print "\n$symbol\t$entrez_id";
    if ($symbols_map{$symbol}){
      my $ids = $symbols_map{$symbol}{entrez_ids};
      $ids->{$entrez_id} = 1;
    }else{
      my %tmp;
      $tmp{$entrez_id} = 1;
      $symbols_map{$symbol}{entrez_ids} = \%tmp;
    }

    #Store synonym to entrez_id mappings
    foreach my $syn (@synonyms_array){
      if ($synonyms_map{$syn}){
        my $ids = $synonyms_map{$syn}{entrez_ids};
        $ids->{$entrez_id} = 1;
      }else{
        my %tmp;
        $tmp{$entrez_id} = 1;
        $synonyms_map{$syn}{entrez_ids} = \%tmp;
      }
    }

    #Store ensembl to entrez_id mappings
    foreach my $ens (sort keys %ensembl_hash){
      if ($ensembl_map{$ens}){
        my $ids = $ensembl_map{$ens}{entrez_ids};
        $ids->{$entrez_id} = 1;
      }else{
        my %tmp;
        $tmp{$entrez_id} = 1;
        $ensembl_map{$ens}{entrez_ids} = \%tmp;
      }
    }
  }
  close (GENE);

  open (ACC, "$gene2accession_file") || die "\n\nCould not open gene2accession file: $gene2accession_file\n\n";
  while(<ACC>){
    chomp($_);
    if ($_ =~ /^\#/){
      next();
    }
    my @line = split("\t", $_);
    my $tax_id = uc($line[0]);
    #Skip all non-human records
    unless ($tax_id eq "9606"){
      next();
    }
    my $entrez_id = uc($line[1]);
    my $prot_id = uc($line[5]);
    my $genome_id = uc($line[7]);

    #Protein accession
    unless ($prot_id eq "-"){
      #If the prot is not defined, skip
      #Clip the version number
      if ($prot_id =~ /(\w+)\.\d+/){
        $prot_id = $1;
      }
      #print "\n$entrez_id\t$prot_id";
      if ($p_acc_map{$prot_id}){
        my $ids = $p_acc_map{$prot_id}{entrez_ids};
        $ids->{$entrez_id} = 1;
      }else{
        my %tmp;
        $tmp{$entrez_id} = 1;
        $p_acc_map{$prot_id}{entrez_ids} = \%tmp;
      }
    }

    #Genomic accession
    unless ($genome_id eq "-"){
      #If the genome accession is not defined, skip
      #Clip the version number
      if ($genome_id =~ /(\w+)\.\d+/){
        $genome_id = $1;
      }
      if ($g_acc_map{$genome_id}){
        my $ids = $g_acc_map{$genome_id}{entrez_ids};
        $ids->{$entrez_id} = 1;
      }else{
        my %tmp;
        $tmp{$entrez_id} = 1;
        $g_acc_map{$genome_id}{entrez_ids} = \%tmp;
      }
    }
  }
  close (ACC);

  #print Dumper %entrez_map;
  #print Dumper %symbols_map;
  #print Dumper %synonyms_map;
  #print Dumper %p_acc_map;

  #Now load ensembl gene id to gene name mappings from a series of legacy ensembl versions
  #Give preference to latest build
  my @files = qw (Ensembl_Genes_Human_v63.txt Ensembl_Genes_Human_v62.txt Ensembl_Genes_Human_v61.txt Ensembl_Genes_Human_v60.txt Ensembl_Genes_Human_v59.txt Ensembl_Genes_Human_v58.txt Ensembl_Genes_Human_v56.txt Ensembl_Genes_Human_v55.txt Ensembl_Genes_Human_v54.txt Ensembl_Genes_Human_v53.txt Ensembl_Genes_Human_v52.txt Ensembl_Genes_Human_v51.txt);

  foreach my $file (@files){
    my $path = "$ensembl_dir"."$file";
    open (ENSG, "$path") || die "\n\nCould not open file: $path\n\n";
    while(<ENSG>){
      chomp($_);
      my @line = split("\t", $_);
      my $ensg_id = uc($line[0]);
      my $ensg_name = uc($line[1]);
      if ($ensg_name =~ /(.*)\.\d+$/){
        $ensg_name = $1;
      }

      unless($ensembl_map2{$ensg_id}){
        $ensembl_map2{$ensg_id}{name}=$ensg_name;
        $ensembl_map2{$ensg_id}{source}=$file;
      }
    }
    close(ENSG);
  }

  $edata{'entrez_ids'} = \%entrez_map;
  $edata{'ensembl_ids'} = \%ensembl_map;
  $edata{'ensembl_ids2'} = \%ensembl_map2;
  $edata{'symbols'} = \%symbols_map;
  $edata{'synonyms'} = \%synonyms_map;
  $edata{'protein_accessions'} = \%p_acc_map;
  $edata{'genome_accessions'} = \%g_acc_map;

  return(\%edata);
}


#######################################################################################################################################################################
#If possible translate the current gene name or ID into an official gene name from Entrez                                                                             #
#######################################################################################################################################################################
sub mapGeneName{
  my %args = @_;
  my $edata = $args{'-entrez_ensembl_data'};
  my $original_name = $args{'-name'};
  my $verbose = $args{'-verbose'};

  my $ensembl_id;
  if (defined($args{'-ensembl_id'})){
     $ensembl_id = $args{'-ensembl_id'};
  }
  
  #Unless a better match is found, the original name will be returned
  my $corrected_name = $original_name; 

  #If the incoming gene name has a trailing version number, strip it off before comparison
  if ($original_name =~ /(.*)\.\d+$/){
    $original_name = $1;
  }

  #Load the mapping hashes
  my $entrez_map = $edata->{'entrez_ids'};
  my $ensembl_map = $edata->{'ensembl_ids'};
  my $ensembl_map2 = $edata->{'ensembl_ids2'};
  my $symbols_map = $edata->{'symbols'};
  my $synonyms_map = $edata->{'synonyms'};
  my $prot_acc_map = $edata->{'protein_accessions'};
  my $genome_acc_map = $edata->{'genome_accessions'};

  my $any_match = 0;
  my @entrez_symbols;
  my $entrez_name_string = '';

  #Try mapping directly to the entrez symbols
  my $entrez_match = 0;
  if ($symbols_map->{$original_name}){
    $entrez_match = 1;
    $any_match = 1;
    my $entrez_ids = $symbols_map->{$original_name}->{entrez_ids};
    foreach my $entrez_id (keys %{$entrez_ids}){
      my $entrez_symbol = $entrez_map->{$entrez_id}->{symbol};
      push (@entrez_symbols, $entrez_symbol);
    }
  }
  if ($entrez_match){
    $entrez_name_string = join(",", @entrez_symbols);
    $corrected_name = $entrez_name_string;
  }

  #Unless a match was already found, try mapping to ensembl IDs and then to entrez symbols
  #This assumes that the 'name' reported is actually an ensembl ID, something that happens routinely in the somatic variation pipeline...
  my $ensembl_match = 0;
  unless ($any_match){
    if ($ensembl_map->{$original_name}){
      $ensembl_match = 1;
      $any_match = 1;
      my $entrez_ids = $ensembl_map->{$original_name}->{entrez_ids};
      foreach my $entrez_id (keys %{$entrez_ids}){
        my $entrez_symbol = $entrez_map->{$entrez_id}->{symbol};
        push (@entrez_symbols, $entrez_symbol);
      }
    }
    if ($ensembl_match){
      $entrez_name_string = join(",", @entrez_symbols);
      $corrected_name = $entrez_name_string;
    }
  }

  #Unless a match was already found, try mapping to ensembl IDs (from Ensembl) and then to Ensembl symbols
  unless ($any_match){
    if ($ensembl_map2->{$original_name}){
      $ensembl_match = 1;
      $any_match = 1;
      $corrected_name = $ensembl_map2->{$original_name}->{name};
    }
  }

  #Unless a match was already found, try mapping to protein accession IDs, and then to Entrez symbols
  unless ($any_match){
    my $protein_acc_match = 0;
    if ($prot_acc_map->{$original_name}){
      $protein_acc_match = 1;
      $any_match = 1;
      my $entrez_ids = $prot_acc_map->{$original_name}->{entrez_ids};
      foreach my $entrez_id (keys %{$entrez_ids}){
        my $entrez_symbol = $entrez_map->{$entrez_id}->{symbol};
        push (@entrez_symbols, $entrez_symbol);
      }
    }
    if ($protein_acc_match){
      $entrez_name_string = join(",", @entrez_symbols);
      $corrected_name = $entrez_name_string;
    }
  }

  #Unless a match was already found, try mapping to genome IDs, and then to Entrez symbols
  unless ($any_match){
    my $genome_acc_match = 0;
    if ($genome_acc_map->{$original_name}){
      $genome_acc_match = 1;
      $any_match = 1;
      my $entrez_ids = $genome_acc_map->{$original_name}->{entrez_ids};
      foreach my $entrez_id (keys %{$entrez_ids}){
        my $entrez_symbol = $entrez_map->{$entrez_id}->{symbol};
        push (@entrez_symbols, $entrez_symbol);
      }
    }
    if ($genome_acc_match){
      $entrez_name_string = join(",", @entrez_symbols);
      $corrected_name = $entrez_name_string;
    }
  }

  #Unless a match was already found, try mapping to Entrez synonyms, and then to Entrez symbols
  #Only allow 1-to-1 matches for synonyms...
  unless ($any_match){
    my $synonyms_match = 0;
    if ($synonyms_map->{$original_name}){
      my $entrez_ids = $synonyms_map->{$original_name}->{entrez_ids};
      my $match_count = keys %{$entrez_ids};
      if ($match_count == 1){
        $synonyms_match = 1;
        $any_match = 1;
        foreach my $entrez_id (keys %{$entrez_ids}){
          my $entrez_symbol = $entrez_map->{$entrez_id}->{symbol};
          push (@entrez_symbols, $entrez_symbol);
        }
      }
    }
    if ($synonyms_match){
      $entrez_name_string = join(",", @entrez_symbols);
      $corrected_name = $entrez_name_string;
    }
  }

  #Unless a match was already found, try mapping to ensembl IDs (from Entrez) and then to entrez symbols - starting with an actual ensembl ID supplied separately
  if ($ensembl_id){
    unless ($any_match){
      if ($ensembl_map->{$ensembl_id}){
        $ensembl_match = 1;
        $any_match = 1;
        my $entrez_ids = $ensembl_map->{$ensembl_id}->{entrez_ids};
        foreach my $entrez_id (keys %{$entrez_ids}){
          my $entrez_symbol = $entrez_map->{$entrez_id}->{symbol};
          push (@entrez_symbols, $entrez_symbol);
        }
      }
      if ($ensembl_match){
        $entrez_name_string = join(",", @entrez_symbols);
        $corrected_name = $entrez_name_string;
      }
    }
  }

  #Unless a match was already found, try mapping to ensembl IDs (from Ensembl) and then to Ensembl symbols - starting with an actual ensembl ID supplied separately
  if ($ensembl_id){
    unless ($any_match){
      if ($ensembl_map2->{$ensembl_id}){
        $ensembl_match = 1;
        $any_match = 1;
        $corrected_name = $ensembl_map2->{$ensembl_id}->{name};
      }
    }
  }

  if ($verbose){
    if ($entrez_name_string eq $original_name){
      print BLUE, "\nSimple Entrez match: $original_name -> $corrected_name", RESET;
    }elsif($corrected_name eq $original_name){
      print YELLOW, "\nNo matches: $original_name -> $corrected_name", RESET;
    }else{
      print GREEN, "\nFixed name: $original_name -> $corrected_name", RESET;
    }
  }
  return($corrected_name);
}


###################################################################################################################################
#Attempt to fix gene names to Entrez                                                                                              #
###################################################################################################################################
sub fixGeneName{
  my %args = @_;
  my $original_gene_name = $args{'-gene'};
  my $entrez_ensembl_data = $args{'-entrez_ensembl_data'};
  my $verbose = $args{'-verbose'};
  my $fixed_gene_name;
  if ($original_gene_name =~ /^ensg\d+/i){
    #If the gene name looks like an Ensembl name, try fixing it twice to allow: Ensembl->Name->Entrez Name
    $fixed_gene_name = &mapGeneName('-entrez_ensembl_data'=>$entrez_ensembl_data, '-name'=>$original_gene_name, '-ensembl_id'=>$original_gene_name, '-verbose'=>$verbose);
    $fixed_gene_name = &mapGeneName('-entrez_ensembl_data'=>$entrez_ensembl_data, '-name'=>$original_gene_name, '-verbose'=>$verbose);
  }else{
    $fixed_gene_name = &mapGeneName('-entrez_ensembl_data'=>$entrez_ensembl_data, '-name'=>$original_gene_name, '-verbose'=>$verbose);
  }
  return($fixed_gene_name)
}


#############################################################################################################################
#Add commas to number.  e.g. 1000000 to 1,000,000                                                                           #
#############################################################################################################################
sub commify {
   local $_  = shift;
   1 while s/^(-?\d+)(\d{3})/$1,$2/;
   return $_;
}


#############################################################################################################################
#Return message describing memory usage of the current process                                                              #
#############################################################################################################################
sub memoryUsage{
  my $pid = $$;
  my $ps_query = `ps -p $pid -o pmem,rss`;
  my @process_info = split ("\n", $ps_query);
  my $memory_usage = '';
  my $memory_usage_p = '';
  if ($process_info[1] =~ /(\S+)\s+(\S+)/){
    $memory_usage_p = $1;
    $memory_usage = $2;
  }
  my $memory_usage_m = sprintf("%.1f", ($memory_usage/1024));
  my $message = "Memory usage: $memory_usage_m Mb ($memory_usage_p%)";
  return($message);
}


#############################################################################################################################
#Parse import the coordinates of the ideogram file using a subroutine                                                       #
#Example input file: /gscmnt/sata132/techd/mgriffit/reference_annotations/hg19/ideogram/ChrBandIdeogram.tsv                 #
#############################################################################################################################
sub importIdeogramData{
  my %args = @_;
  my $ideogram_file = $args{'-ideogram_file'};
  unless (-e $ideogram_file){
    print RED, "\n\n&importIdeogramData -> could not find ideogram file\n\n", RESET;
    exit();
  }
  open (IDEO, $ideogram_file) || die "\n\nCould not open ideogram file: $ideogram_file\n\n";
  my %ideo_data;
  while(<IDEO>){
    chomp($_);
    my @line = split("\t", $_);
    if ($_ =~ /^\#/){
      next();
    }
    my $chr = $line[0];
    my $chr_start = $line[1];
    my $chr_end = $line[2];
    my $name = $line[3];
    my $giemsa_stain = $line[4];

    my $chr_name = '';
    if ($chr =~ /chr(\w+)/){
      $chr_name = $1;
    }else{
      print RED, "\n\n&importIdeogramData -> could not understand chromosome name format\n\n", RESET;
      exit();
    }
    my $cytoname = "$chr_name"."$name";
    if ($ideo_data{$chr}){
      my $cytobands = $ideo_data{$chr}{cytobands};
      $cytobands->{$cytoname}->{chr_start} = $chr_start;
      $cytobands->{$cytoname}->{chr_end} = $chr_end;
      $cytobands->{$cytoname}->{giemsa_stain} = $giemsa_stain;
      $cytobands->{$cytoname}->{name} = $name;
    }else{
      my %tmp;
      $tmp{$cytoname}{chr_start} = $chr_start;
      $tmp{$cytoname}{chr_end} = $chr_end;
      $tmp{$cytoname}{giemsa_stain} = $giemsa_stain;
      $tmp{$cytoname}{name} = $name;
      $ideo_data{$chr}{cytobands} = \%tmp;
    }
  }
  close(IDEO);
  return(\%ideo_data);
}


#############################################################################################################################
#Given some chromosome coordinates and an object of ideogram data, generate a cytoband string                               #
#############################################################################################################################
sub getCytoband{
  my %args = @_;
  my $ideo_data = $args{'-ideo_data'};
  my $chr = $args{'-chr'};
  my $chr_start = $args{'-chr_start'};
  my $chr_end = $args{'-chr_end'};
  my $cytoband_string = '';

  unless($cytoband_string){
    $cytoband_string = "NA";
  }

  if ($ideo_data->{$chr}){
    my $cytobands = $ideo_data->{$chr}->{cytobands};
    my %matches;
    my $m = 0;
    foreach my $cyto (sort {$cytobands->{$a}->{chr_start} <=> $cytobands->{$b}->{chr_start}} keys %{$cytobands}){
      my $cyto_start = $cytobands->{$cyto}->{chr_start};
      my $cyto_end = $cytobands->{$cyto}->{chr_end};
      my $cyto_name = $cytobands->{$cyto}->{name};
      my $match_found = 0;
      #If either end of the input range is within the cytoband, or it flanks the cytoband completely, consider it a match
      if ($chr_start >= $cyto_start && $chr_start <= $cyto_end){$match_found = 1;}
      if ($chr_end >= $cyto_start && $chr_end <= $cyto_end){$match_found = 1;}
      if ($chr_start <= $cyto_start && $chr_end >= $cyto_end){$match_found = 1;}
      if ($match_found){
        $m++;
        $matches{$m}{cytoband} = $cyto;
      }
    }
    my $match_count = keys %matches;
    if ($match_count == 1){
      $cytoband_string = $matches{1}{cytoband};
    }elsif($match_count > 1){
      $cytoband_string = $matches{1}{cytoband}." - ".$matches{$match_count}{cytoband};
    }
  }else{
    $cytoband_string = "NA";
  }

  return($cytoband_string);
}


#############################################################################################################################
#Get column position                                                                                                        #
#############################################################################################################################
sub getColumnPosition{
  my %args = @_;
  my $path = $args{'-path'};
  my $colname = $args{'-column_name'};
  my $desired_column_position;

  #Get the header line from a file, determine the position (0 based) of the requested column name
  open (IN, "$path") || die "\n\nCould not open input file: $path\n\n";
  my $line = <IN>;
  close (IN);

  chomp($line);
  my @header = split("\t", $line);
  my %columns;
  my $p = 0;
  foreach my $col (@header){
    $columns{$col}{position} = $p;    
    $p++;
  }

  if (defined($columns{$colname})){
    $desired_column_position = $columns{$colname}{position};
  }else{
    print RED, "\n\n&getColumnPosition - The requested column name ($colname) was not found in the specified file ($path)\n\n", RESET;
    exit();
  }

  return($desired_column_position);
}



1;

