#!/gsc/bin/perl
# Copyright (C) 2008 Washington University in St. Louis
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


use strict;
use warnings;
#use lib '/gscuser/kchen/454-TSP-Test/Analysis/Ken/scripts/';
use Genome::Model::Tools::Pyroscan::CrossMatch;
use Genome::Model::Tools::Pyroscan::Detector;
use Bio::SeqIO;
use Getopt::Long;
use Pod::Usage;

#default parameters
my ($gene,$fa_refseq,$f_tumor_qual,$f_cm_tumor,$f_normal_qual,$f_cm_normal);
my $Pvalue=1e-6;
my $floor_ratio_tumor=0;
my $floor_ratio_normal=0;
my $floor_indel_size=3;
my $f_poslst;

my $status=&GetOptions(
		       "gene=s" => \$gene,  #Hugo Gene
		       "refseq=s" => \$fa_refseq,  # reference sequence
		       "qt=s" => \$f_tumor_qual,    # .qual files for the tumor reads
		       "cmt=s"   => \$f_cm_tumor,      # cross-match alignment for the tumor reads
		       "qn=s" => \$f_normal_qual,   # .qual files for the normal reads
		       "cmn=s" => \$f_cm_normal,  # cross-match alignment for the normal reads
		       "pvalue=s" => \$Pvalue, # P value stringency
		       "rt=s"  => \$floor_ratio_tumor,  # baseline variant/wildtype read ratio in tumor
		       "rn=s" => \$floor_ratio_normal,  # baseline variant/wildtype read ratio in normal
		       "indel=i" => \$floor_indel_size,   # minimum indel size to report
		       "lstpos=s" => \$f_poslst   #list of positions for genotyping
		      );

print "#gene: $gene\n" if(defined $gene);
print "#refseq: $fa_refseq\n" if(defined $fa_refseq);
print "#tumor reads quality file: $f_tumor_qual\n" if(defined $f_tumor_qual);
print "#tumor cross-match alignment file: $f_cm_tumor\n" if(defined $f_cm_tumor);
print "#normal reads quality file: $f_normal_qual\n" if(defined $f_normal_qual);
print "#normal cross-match alignment file: $f_cm_normal\n" if(defined $f_cm_normal);
print "#P value cutoff: $Pvalue\n" if(defined $Pvalue);
print "#baseline variant/wildtype read ratio in tumor: $floor_ratio_tumor\n" if(defined $floor_ratio_tumor);
print "#baseline variant/wildtype read ratio in normal: $floor_ratio_normal\n" if(defined $floor_ratio_normal);
print "#only report indels longer than: $floor_indel_size bp\n";

my $f_gene_header="/gscuser/kchen/454-TSP-Test/Analysis/Ken/data/GeneHeaders.txt";
my $gene_info=&GetGeneInfo($f_gene_header,$gene);
my $refseq=&getRefSeq($fa_refseq);

#evaluation
my $f_maf="/gscuser/kchen/454-TSP-Test/Analysis/Ken/data/valid-germline-SNPs.txt";
my $f_dbsnp="/gscuser/kchen/454-TSP-Test/Analysis/Ken/data/dbsnp127_251TSPgenes.txt";
my $Mutation=&ReadMAF($f_maf,$gene_info,$floor_indel_size);
my $dbSNP=&ReadDbSNP($f_dbsnp,$gene_info,$floor_indel_size);

my @poses=&Readlist($f_poslst);

my $var_normal;
if(defined $f_cm_normal && defined $f_normal_qual){  # case/control analysis

  my $tumor_cm=new Genome::Model::Tools::Pyroscan::CrossMatch(fin=>$f_cm_tumor,loci=>$gene_info);
  my $normal_cm=new Genome::Model::Tools::Pyroscan::CrossMatch(fin=>$f_cm_normal,loci=>$gene_info);

  my $detector=new Genome::Model::Tools::Pyroscan::Detector();
  my $var=$detector->MutDetect(\@poses,$tumor_cm,$floor_ratio_tumor,$f_tumor_qual,$normal_cm,$floor_ratio_normal,$f_normal_qual,$Pvalue, $floor_indel_size, $refseq, $gene_info);

  &EvaluatePair($var,10,$gene_info,$Mutation,$dbSNP);
}
else{  # cohort analysis

  my $tumor_cm=new Genome::Model::Tools::Pyroscan::CrossMatch(fin=>$f_cm_tumor,loci=>$gene_info);
  my $tumor_detect=new Genome::Model::Tools::Pyroscan::Detector();
  my $var_tumor=$tumor_detect->VarDetect(\@poses,$tumor_cm,$floor_ratio_tumor,$Pvalue, $floor_indel_size, $refseq,$f_tumor_qual, $gene_info);
  &Evaluate($var_tumor,10,$gene_info,$Mutation,$dbSNP);
}

sub Readlist{
  my ($f_poslst)=@_;
  my @pos;
  if(defined $f_poslst){
    open(LST,"<$f_poslst") || die "unable to open $f_poslst\n";
    while(<LST>){
      chomp;
      push @pos,$_;
    }
    close(LST);
  }
  return @pos;
}

sub GetGeneInfo{
  my ($f_fasta_header,$gene)=@_;
  open(HEADER,"<$f_fasta_header") || die "unable to open $f_fasta_header\n";
  my $info;
  while(<HEADER>){
    chomp;
    ($info->{gene},$info->{chr},$info->{start},$info->{end},$info->{ori})=($_=~/GeneName\:(\S+)\,.+Chr\:(\S+)\,.+Coords (\d+)\-(\d+)\, Ori \((\S)\)/);
    last if($info->{gene}=~/^$gene$/i);
  }
  close(HEADER);
  return $info;
}

sub ReadMAF{
  my ($f_maf,$info,$floor_indel_size)=@_;
  my ($gene,$chr,$start,$end,$ori)=($info->{gene},$info->{chr},$info->{start},$info->{end},$info->{ori});
  my $nindels=0;
  my $nvars=0;
  open(MAF, "<$f_maf") || die "unable to open $f_maf\n";
  my %variants;
  $_=<MAF>;
  while(<MAF>){
    chomp;
    my $var;
    ($var->{Gene},$var->{Entrez_Gene_Id},$var->{Center},$var->{NCBI_Build},$var->{Chromosome},$var->{Start},$var->{End},$var->{strand},$var->{class},$var->{type},$var->{Reference_Allele},$var->{Tumor_Seq_Allele1},$var->{Tumor_Seq_Allele2},$var->{dbSNP_RS},$var->{dbSNP_Val_Status},$var->{Tumor_Sample_Barcode},$var->{Matched_Norm_Sample_Barcode},$var->{Match_Norm_Seq_Allele1},$var->{Match_Norm_Seq_Allele2},$var->{Tumor_Validation_Allele1},$var->{Tumor_Validation_Allele2},$var->{Match_Norm_Validation_Allele1},$var->{Match_Norm_Validation_Allele2},$var->{Verification_Status},$var->{Validation_Status},$var->{Mutation_Status})=split /\t/;
    next unless($var->{Gene}=~/^$gene$/i);
    next if($var->{Validation_Status}=~/wildtype/i);

    my $indelsize;
    if(($var->{type}=~/del/i) || ($var->{type}=~/ins/i)){
      my $allele1=$var->{Tumor_Seq_Allele1};
      my $allele2=$var->{Tumor_Seq_Allele2};
      $allele1=~s/\-//g;
      $allele2=~s/\-//g;
      $indelsize=abs(length($allele1)-length($allele2));
    }

    next if(defined $indelsize && $indelsize<$floor_indel_size);  #skip small indels

    #next if($var->{type}!~/SNP/i);
    $nindels++ if(defined $indelsize);
    $nvars++;
    if($ori=~/\-/){  #- strand gene
      $var->{Tumor_Seq_Allele1}=~tr/ACGT/TGCA/;
      $var->{Tumor_Seq_Allele2}=~tr/ACGT/TGCA/;
    }
    $variants{$var->{Start}}=$var;
  }
  close(MAF);
  print "#$nvars variants loaded, $nindels indels\n";

  return \%variants;
}

sub ReadDbSNP{
  #from Ling's file
  my ($f_dbsnp,$info,$floor_indel_size)=@_;
  my ($gene,$chr,$start,$end,$ori)=($info->{gene},$info->{chr},$info->{start},$info->{end},$info->{ori});
  open(dbSNP, "<$f_dbsnp") || die "unable to open $f_dbsnp\n";
  my %variants;
  $_=<dbSNP>;
  while(<dbSNP>){
    chomp;
    my $var;
    ($var->{Gene},$var->{Chromosome},$var->{Start},$var->{End},$var->{rs},$var->{AlleleString})=split /\s+/;
    next unless($var->{Gene}=~/^$gene$/i);
    if($ori=~/\-/){  #- strand gene
      $var->{AlleleString}=~tr/ACGT/TGCA/;
    }
    $variants{$var->{Start}}=$var;
  }
  close(dbSNP);

  return \%variants;
}

sub getRefSeq{
  my ($f_fasta)=@_;
  my $stream = Bio::SeqIO->newFh(-file =>$f_fasta , -format => 'Fasta'); # read from standard input
  my $fasta;
  my $seq = <$stream>;

  return $seq->seq;
}

sub Evaluate{
  my ($Variants,$offset,$loci_info,$Mutation,$dbSNP)=@_;

  my @mutPos=keys %{$Mutation};
  my $nMut=0;
  my $nVarCalled=0;
  my $nDbSNP=0;
  foreach my $pos(sort {$a<=>$b} keys %{$Variants}){
    my $var=$$Variants{$pos};
    my $var_type=($var->{variant}=~/[DI]/)?'INDEL':'SNP';
    my $gpos=&ToGenomic($pos,$loci_info);
    my $b_type=0;
    my $k=0;

    if($$Mutation{$gpos}){
      $b_type=1;
    }
    elsif($$dbSNP{$gpos}){
      $b_type=2;
    }
    elsif($var_type eq 'INDEL'){
      for($k=-$offset;$k<=$offset;$k++){
	if($$Mutation{$gpos+$k} &&
	   ($$Mutation{$gpos+$k}->{type} eq 'INS' ||
	    $$Mutation{$gpos+$k}->{type} eq 'DEL')
	  ){
	  $b_type=1;
	  last;
	}
      }
      for($k=-$offset;$k<=$offset;$k++){
	if($$dbSNP{$gpos+$k} && $$dbSNP{$gpos+$k}->{AlleleString}=~/\-/){
	  $b_type=2;
	  last;
	}
      }
    }
    else{}

    $gpos=$gpos+$k;
    &PrintVar($pos,$var);
    if($b_type==1){
      $nMut++;
      $$Mutation{$gpos}->{Detected}=1;
      printf "\tMut\t%d\t%s/%s\n",$$Mutation{$gpos}->{Start},$$Mutation{$gpos}->{Tumor_Seq_Allele1},$$Mutation{$gpos}->{Tumor_Seq_Allele2};
    }
    elsif($b_type==2){
      $nDbSNP++;
      printf "\tdbSNP\t%d\t%s\n",$$dbSNP{$gpos}->{Start},$$dbSNP{$gpos}->{AlleleString};
    }
    else{
      printf "\tFP\n";
    }
    $nVarCalled++;

  }

  foreach my $pos(sort keys %{$Mutation}){
    my $var=$$Mutation{$pos};
    next if($var->{Detected});
    my $refpos=ToRefSeq($pos,$loci_info);
    print "MISS\t$var->{Gene}\t$refpos\t$var->{Entrez_Gene_Id}\t$var->{Center}\t$var->{NCBI_Build}\t$var->{Chromosome}\t$var->{Start}\t$var->{End}\t$var->{strand}\t$var->{class}\t$var->{type}\t$var->{Reference_Allele}\t$var->{Tumor_Seq_Allele1}\t$var->{Tumor_Seq_Allele2}\t$var->{dbSNP_RS}\t$var->{dbSNP_Val_Status}\t$var->{Tumor_Sample_Barcode}\t$var->{Matched_Norm_Sample_Barcode}\t$var->{Match_Norm_Seq_Allele1}\t$var->{Match_Norm_Seq_Allele2}\t$var->{Tumor_Validation_Allele1}\t$var->{Tumor_Validation_Allele2}\t$var->{Match_Norm_Validation_Allele1}\t$var->{Match_Norm_Validation_Allele2}\t$var->{Verification_Status}\t$var->{Validation_Status}\t$var->{Mutation_Status}\n";
  }

  my $sensitivity=($#mutPos+1>0)?$nMut*100/($#mutPos+1):100;
  my $specificity=($nVarCalled>0)?($nDbSNP+$nMut)*100/$nVarCalled:100;

  printf "sen: %d/%d\(%.2f%%\)\tspe: %d/%d\(%.2f%%\)\n",$nMut,$#mutPos+1,$sensitivity,$nDbSNP+$nMut,$nVarCalled,$specificity;

}

sub EvaluatePair{
  my ($Vars,$offset,$loci_info,$Mutation,$dbSNP)=@_;

  my @mutPos=keys %{$Mutation};
  my $nMut=0;
  my $nVarCalled=0;
  my $nDbSNP=0;

  foreach my $pos(sort {$a<=>$b} keys %{$Vars}){
    my $var=$$Vars{$pos};
    my $gpos=&ToGenomic($pos,$loci_info);

    my $mut_type=$var->{status};
    my $Case=$var->{case};
    my $Control=$var->{control};

    my $var_type;
    if(defined $Case){
      $var_type=($Case->{variant}=~/[DI]/)?'INDEL':'SNP';
    }
    elsif(defined $Control){
      $var_type=($Control->{variant}=~/[DI]/)?'INDEL':'SNP';
    }
    else{}

    my $b_type=0;
    my $k=0;
    if($$Mutation{$gpos}){
      $b_type=1;

    }
    elsif($$dbSNP{$gpos}){
      $b_type=2;
    }
    elsif($var_type eq 'INDEL'){
      for($k=-$offset;$k<=$offset;$k++){
	if($$Mutation{$gpos+$k} &&
	   ($$Mutation{$gpos+$k}->{type} eq 'INS' ||
	    $$Mutation{$gpos+$k}->{type} eq 'DEL')
	  ){
	  $b_type=1;
	  last;
	}
      }
      for($k=-$offset;$k<=$offset;$k++){
	if($$dbSNP{$gpos+$k} && $$dbSNP{$gpos+$k}->{AlleleString}=~/\-/){
	  $b_type=2;
	  last;
	}
      }
    }
    else{}

    $gpos=$gpos+$k;
    &PrintPairVar($pos,$var,$Case,$Control);
    if($b_type==1){
      $nMut++;
      $$Mutation{$gpos}->{Detected}=$mut_type;
      printf "Mut\t%d\t%s/%s\t%s\n",$$Mutation{$gpos}->{Start},$$Mutation{$gpos}->{Tumor_Seq_Allele1},$$Mutation{$gpos}->{Tumor_Seq_Allele2},$$Mutation{$gpos}->{Mutation_Status};
    }
    elsif($b_type==2){
      $nDbSNP++;
      printf "dbSNP\t%d\t%s\n",$$dbSNP{$gpos}->{Start},$$dbSNP{$gpos}->{AlleleString};
    }
    else{
      printf "FP\n";
    }
    $nVarCalled++;
  }

  foreach my $pos(sort keys %{$Mutation}){
    my $var=$$Mutation{$pos};
    next if($var->{Detected});
    my $refpos=ToRefSeq($pos,$loci_info);
    print "MISS\t$var->{Gene}\t$refpos\t$var->{Entrez_Gene_Id}\t$var->{Center}\t$var->{NCBI_Build}\t$var->{Chromosome}\t$var->{Start}\t$var->{End}\t$var->{strand}\t$var->{class}\t$var->{type}\t$var->{Reference_Allele}\t$var->{Tumor_Seq_Allele1}\t$var->{Tumor_Seq_Allele2}\t$var->{dbSNP_RS}\t$var->{dbSNP_Val_Status}\t$var->{Tumor_Sample_Barcode}\t$var->{Matched_Norm_Sample_Barcode}\t$var->{Match_Norm_Seq_Allele1}\t$var->{Match_Norm_Seq_Allele2}\t$var->{Tumor_Validation_Allele1}\t$var->{Tumor_Validation_Allele2}\t$var->{Match_Norm_Validation_Allele1}\t$var->{Match_Norm_Validation_Allele2}\t$var->{Verification_Status}\t$var->{Validation_Status}\t$var->{Mutation_Status}\n";
  }

  my $sensitivity=($#mutPos+1>0)?$nMut*100/($#mutPos+1):100;
  my $specificity=($nVarCalled>0)?($nDbSNP+$nMut)*100/$nVarCalled:100;

  printf "sen: %d/%d\(%.2f%%\)\tspe: %d/%d\(%.2f%%\)\n",$nMut,$#mutPos+1,$sensitivity,$nDbSNP+$nMut,$nVarCalled,$specificity;
}

sub PrintPairVar{
  my ($pos,$var,$case,$control)=@_;

  printf "%d\t%s\t",$pos,$var->{status};
  if(defined $case){
    my $case_type=($case->{variant}=~/[DI]/)?'INDEL':'SNP';
    my $case_ratio=($case->{wt_readcount}>0)?$case->{var_readcount}/$case->{wt_readcount}:-1;
    printf "%s\t%d\t%s\t%d\t%s\t%d\t%.6f",$case_type,$case->{total_readcount},$var->{wt},$case->{wt_readcount},$case->{variant},$case->{var_readcount},$case_ratio;
    print "\t$case->{Pvalue}\t";
  }

  if(defined $control){
    my $control_type=($control->{variant}=~/[DI]/)?'INDEL':'SNP';
    my $control_ratio=($control->{wt_readcount}>0)?$control->{var_readcount}/$control->{wt_readcount}:-1;
    printf "%s\t%d\t%s\t%d\t%s\t%d\t%.6f",$control_type,$control->{total_readcount},$var->{wt},$control->{wt_readcount},$control->{variant},$control->{var_readcount},$control_ratio;
    print "\t$control->{Pvalue}\t";
  }
}

sub PrintVar{
  my ($pos,$var)=@_;
  my $var_type=($var->{variant}=~/[DI]/)?'INDEL':'SNP';
  my $ratio=($var->{wt_readcount}>0)?$var->{var_readcount}/$var->{wt_readcount}:-1;
  printf "%d\t%s\t%d\t%s\t%d\t%s\t%d\t%.6f",$pos,$var_type,$var->{total_readcount},$var->{wt},$var->{wt_readcount},$var->{variant},$var->{var_readcount},$ratio;
  print "\t$var->{Pvalue}";
}

sub ToGenomic{
  my ($pos,$loci)=@_;
  my $gpos;
  if($loci->{ori}=~/\+/){  #plus strand gene
    $gpos=$pos+$loci->{start}-1;
  }
  else{
    $gpos=$loci->{end}-$pos+1;
  }
  return $gpos;
}

sub ToRefSeq{
  my ($gpos,$loci)=@_;
  my $refpos;
  if($loci->{ori}=~/\+/){  #plus strand gene
    $refpos=$gpos-$loci->{start}+1;
  }
  else{
    $refpos=$loci->{end}-$gpos+1;
  }
  return $refpos;
}
