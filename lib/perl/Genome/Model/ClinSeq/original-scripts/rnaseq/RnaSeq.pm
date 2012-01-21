package rnaseq::RnaSeq;
require Exporter;

@ISA = qw( Exporter );
@EXPORT = qw();

@EXPORT_OK = qw(
                &parseFpkmFile &mergeIsoformsFile
               );

%EXPORT_TAGS = (
                all => [qw(&parseFpkmFile &mergeIsoformsFile)]
               );

use strict;
use warnings;
use Data::Dumper;
use Term::ANSIColor qw(:constants);
use lib File::Basename::dirname(__FILE__).'/..';
use ClinSeq qw(:all);


#################################################################################################################
#Parse the genes.fpkm_trackin file                                                                              #
#################################################################################################################
sub parseFpkmFile{
  my %args = @_;
  my $infile = $args{'-infile'};
  my $entrez_ensembl_data = $args{'-entrez_ensembl_data'};
  my $verbose = $args{'-verbose'};
  my $outfile;
  if (defined($args{'-outfile'})){
    $outfile = $args{'-outfile'};
  }

  if ($verbose){
    print BLUE, "\n\nParsing: $infile", RESET;
  }
  my %fpkm;
  my $header = 1;
  my $rc = 0;     #record count
  my %columns;
  open (FPKM, "$infile") || die "\n\nCould not open gene file: $infile\n\n";
  while(<FPKM>){
    chomp($_);
    my @line = split("\t", $_);
    if ($header == 1){
      $header = 0;
      my $p = 0;
      foreach my $head (@line){
        $columns{$head}{position} = $p;
        $p++;
      }
      next();
    }
    $rc++;
    
    my $tracking_id = $line[$columns{'tracking_id'}{position}];
    my $gene_id = $line[$columns{'gene_id'}{position}];
    my $locus = $line[$columns{'locus'}{position}];
    my $length = $line[$columns{'length'}{position}];
    my $coverage = $line[$columns{'coverage'}{position}];
    my $FPKM = $line[$columns{'FPKM'}{position}];
    my $FPKM_conf_lo = $line[$columns{'FPKM_conf_lo'}{position}];
    my $FPKM_conf_hi = $line[$columns{'FPKM_conf_hi'}{position}];
    my $FPKM_status;
    if ($columns{'FPKM_status'}){
      $FPKM_status = $line[$columns{'FPKM_status'}{position}];
    }elsif($columns{'status'}){
      $FPKM_status = $line[$columns{'status'}{position}];
    }else{
      print RED, "\n\nRequired column not found: 'FPKM_status' or 'status'", RESET;
      exit();
    }

    #Fix gene name and create a new column for this name
    my $fixed_gene_name = &fixGeneName('-gene'=>$gene_id, '-entrez_ensembl_data'=>$entrez_ensembl_data, '-verbose'=>0);

    #Key on tracking id AND locus coordinates
    my $key = "$tracking_id"."|"."$locus";

    $fpkm{$key}{record_count} = $rc;
    $fpkm{$key}{tracking_id} = $tracking_id;
    $fpkm{$key}{mapped_gene_name} = $fixed_gene_name;
    $fpkm{$key}{gene_id} = $gene_id;
    $fpkm{$key}{locus} = $locus;
    $fpkm{$key}{length} = $length;
    $fpkm{$key}{coverage} = $coverage;
    $fpkm{$key}{FPKM} = $FPKM;
    $fpkm{$key}{FPKM_conf_lo} = $FPKM_conf_lo;
    $fpkm{$key}{FPKM_conf_hi} = $FPKM_conf_hi;
    $fpkm{$key}{FPKM_status} = $FPKM_status;
  }
  close(FPKM);

  my $gc = keys %fpkm;
  unless ($gc == $rc){
    print RED, "\n\nFound $gc distinct gene|coord entries but $rc data lines - not good...\n\n", RESET;
    exit();
  }

  #Print an outfile sorted on the key
  if ($outfile){
    open (OUT, ">$outfile") || die "\n\nCould not open gene file: $infile\n\n";
    print OUT "tracking_id\tmapped_gene_name\tgene_id\tlocus\tlength\tcoverage\tFPKM\tFPKM_conf_lo\tFPKM_conf_hi\tFPKM_status\n";
    foreach my $key (sort {$a cmp $b} keys %fpkm){
      print OUT "$fpkm{$key}{tracking_id}\t$fpkm{$key}{mapped_gene_name}\t$fpkm{$key}{gene_id}\t$fpkm{$key}{locus}\t$fpkm{$key}{length}\t$fpkm{$key}{coverage}\t$fpkm{$key}{FPKM}\t$fpkm{$key}{FPKM_conf_lo}\t$fpkm{$key}{FPKM_conf_hi}\t$fpkm{$key}{FPKM_status}\n";
    }
    close(OUT);
  }

  return(\%fpkm);
}


#################################################################################################################
#Merge the isoforms.fpkm_tracking file to the gene level                                                        #
#################################################################################################################
sub mergeIsoformsFile{
  my %args = @_;
  my $infile = $args{'-infile'};
  my $entrez_ensembl_data = $args{'-entrez_ensembl_data'};
  my $verbose = $args{'-verbose'};
  my $outfile;
  if (defined($args{'-outfile'})){
    $outfile = $args{'-outfile'};
  }

  if ($verbose){
    print BLUE, "\n\nParsing and merging to gene level: $infile", RESET;
  }
  my %trans;
  my %genes;
  my $header = 1;
  my $rc = 0;     #record count
  my %columns;
  open (TRANS, "$infile") || die "\n\nCould not open gene file: $infile\n\n";
  while(<TRANS>){
    chomp($_);
    my @line = split("\t", $_);
    if ($header == 1){
      $header = 0;
      my $p = 0;
      foreach my $head (@line){
        $columns{$head}{position} = $p;
        $p++;
      }
      next();
    }
    $rc++;
   
    #Note.  The tracking ID in this file should be an Ensembl transcript id.  Use this ID and the specified ensembl version to look up the ENSG ID
    my $tracking_id = $line[$columns{'tracking_id'}{position}];
    my $gene_id = $line[$columns{'gene_id'}{position}];
    my $locus = $line[$columns{'locus'}{position}];
    my $length = $line[$columns{'length'}{position}];
    my $coverage = $line[$columns{'coverage'}{position}];
    my $FPKM = $line[$columns{'FPKM'}{position}];
    my $FPKM_conf_lo = $line[$columns{'FPKM_conf_lo'}{position}];
    my $FPKM_conf_hi = $line[$columns{'FPKM_conf_hi'}{position}];
    my $FPKM_status;
    if ($columns{'FPKM_status'}){
      $FPKM_status = $line[$columns{'FPKM_status'}{position}];
    }elsif($columns{'status'}){
      $FPKM_status = $line[$columns{'status'}{position}];
    }else{
      print RED, "\n\nRequired column not found: 'FPKM_status' or 'status'", RESET;
      exit();
    }
 
    #Fix gene name and create a new column for this name
    my $fixed_gene_name = &fixGeneName('-gene'=>$gene_id, '-entrez_ensembl_data'=>$entrez_ensembl_data, '-verbose'=>0);

    $trans{$tracking_id}{record_count} = $rc;

    #Get coords from locus
    my $chr;
    my $chr_start;
    my $chr_end;
    if ($locus =~ /(\w+)\:(\d+)\-(\d+)/){
      $chr = $1;
      $chr_start = $2;
      $chr_end = $3;
    }else{
      print RED, "\n\nlocus format not understood: $locus\n\n", RESET;
      exit();
    }

    if ($genes{$gene_id}){
      if ($chr_start <  $genes{$gene_id}{chr_start}){$genes{$gene_id}{chr_start} = $chr_start;}
      if ($chr_end >  $genes{$gene_id}{chr_end}){$genes{$gene_id}{chr_end} = $chr_end;}
      $genes{$gene_id}{coverage} += $coverage;
      $genes{$gene_id}{FPKM} += $FPKM;
      $genes{$gene_id}{FPKM_conf_lo} += $FPKM_conf_lo;
      $genes{$gene_id}{FPKM_conf_hi} += $FPKM_conf_hi;
      $genes{$gene_id}{FPKM_status} = "na";
      $genes{$gene_id}{transcript_count}++;
    }else{
      $genes{$gene_id}{mapped_gene_name} = $fixed_gene_name;
      $genes{$gene_id}{chr} = $chr;
      $genes{$gene_id}{chr_start} = $chr_start;
      $genes{$gene_id}{chr_end} = $chr_end;
      $genes{$gene_id}{coverage} = $coverage;
      $genes{$gene_id}{FPKM} = $FPKM;
      $genes{$gene_id}{FPKM_conf_lo} = $FPKM_conf_lo;
      $genes{$gene_id}{FPKM_conf_hi} = $FPKM_conf_hi;
      $genes{$gene_id}{FPKM_status} = "na";
      $genes{$gene_id}{transcript_count} = 1;
    }
  }
  close(TRANS);

  my $tc = keys %trans;
  unless ($tc == $rc){
    print RED, "\n\nFound $tc distinct transcript entries but $rc data lines - not good...\n\n", RESET;
    exit();
  }

  #Now go through the transcripts and merge down to genes, combining the coverage and FPKM values (cumulatively), coordinates (outer coords), and calculating a new length
  #Print an outfile sorted on the key
  if ($outfile){
    open (OUT, ">$outfile") || die "\n\nCould not open gene file: $infile\n\n";
    print OUT "tracking_id\tmapped_gene_name\tgene_id\tlocus\tlength\tcoverage\tFPKM\tFPKM_conf_lo\tFPKM_conf_hi\tFPKM_status\n";
    foreach my $gene_id (sort {$a cmp $b} keys %genes){
      my $locus = "$genes{$gene_id}{chr}:$genes{$gene_id}{chr_start}-$genes{$gene_id}{chr_end}";
      my $length = "-";
      print OUT "$gene_id\t$genes{$gene_id}{mapped_gene_name}\t$gene_id\t$locus\t$length\t$genes{$gene_id}{coverage}\t$genes{$gene_id}{FPKM}\t$genes{$gene_id}{FPKM_conf_lo}\t$genes{$gene_id}{FPKM_conf_hi}\t$genes{$gene_id}{FPKM_status}\n";
    }
    close(OUT);
  }
  return(\%genes);
}


1;

