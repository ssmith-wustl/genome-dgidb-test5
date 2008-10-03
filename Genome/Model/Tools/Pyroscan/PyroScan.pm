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


########################################################################################
# Author: Ken Chen (kchen@genome.wustl.edu)
# Date: July, 2008
# This module can used to detect SNP and indels based on the cross-match alignment
# of 454 reads to the reference sequences using Fisher's Exact Test
########################################################################################

use strict;
use warnings;
use Statistics::Distributions;
use lib '/gscuser/kchen/454-Test-Set/Analysis/Ken/scripts/';
use FET;
package PyroScan;

sub new{
  my ($class, %arg) = @_;
  my $self={
	    min_base_qual=>$arg{MinBaseQual} || 20,
	    homopolymer_size=>$arg{HomoPolymerIndelSize} || 2
	   };
  bless($self, $class || ref($class));
  return $self;
}

sub VarDetect{
  my ($self,$poslst,$cm,$floor_ratio,$f_qual,$Pvalue_Thresh,$floor_indel_size,$refseq)=@_;

  my $Min_Reads=&EstimateMinReads($Pvalue_Thresh,$floor_ratio);
  print "#this is a cohort study\n";
  print "#minimum $Min_Reads Reads required to achieve P<=$Pvalue_Thresh at floor_ratio=$floor_ratio\n";

  die "quality files are not specified\n" if(!defined $f_qual);

  my %Vars;
  my @DCposes;
  if($#$poslst>=0){
    @DCposes=@{$poslst};
  }
  else{
    @DCposes=keys %{$cm->{dcpos}}; #discrepant position
  }

  foreach my $refpos(@DCposes){
    next if(!defined $cm->{dcpos}{$refpos});

    my @DCreads=@{$cm->{dcpos}{$refpos}};
    next if($#DCreads+1<$Min_Reads);

    my ($Allele_info)=$cm->GetAlleleInfo($refseq,$f_qual,$refpos,$Min_Reads);
    my $refbase=substr $refseq, $refpos-1, 1;
    ###############
    # Call Allele #
    ###############
    my $var_case=VariantCall($Allele_info,$Min_Reads,$floor_ratio,$Pvalue_Thresh,$floor_indel_size);
    next if($var_case->{Pvalue}>$Pvalue_Thresh);
    my $var;
    $var->{wt}=$refbase;
    $var->{case}=$var_case;

    $Vars{$refpos}=$var;

  }
  return \%Vars;
}

sub MutDetect{
  my ($self,$poslst,$cm_case,$floor_ratio_case,$f_qual_case,$cm_control,$floor_ratio_control,$f_qual_control,$Pvalue_Thresh,$floor_indel_size,$refseq)=@_;
  print "#this is a case/control study\n";
  my $Min_Reads_case=&EstimateMinReads($Pvalue_Thresh,$floor_ratio_case);
  print "#minimum $Min_Reads_case reads required for cases to achieve P<=$Pvalue_Thresh at floor_ratio=$floor_ratio_case\n";
  my $Min_Reads_control=&EstimateMinReads($Pvalue_Thresh,$floor_ratio_control);
  print "#minimum $Min_Reads_control control reads required for controls to achieve P<=$Pvalue_Thresh at floor_ratio=$floor_ratio_control\n";

  die "quality files are not specified\n" if(!defined $f_qual_case);
  die "quality files are not specified\n" if(!defined $f_qual_control);

  my %Vars;
  my @DCposes_case;
  my @DCposes_control;

  if($#$poslst>=0){
    @DCposes_case=@{$poslst};
    @DCposes_control=@{$poslst};
  }
  else{
    @DCposes_case=keys %{$cm_case->{dcpos}}; #discrepant position
    @DCposes_control=keys %{$cm_control->{dcpos}}; #discrepant position from control
  }

  my %Poses;
  foreach my $refpos(@DCposes_case){
    next if(defined $Poses{$refpos});
    $Poses{$refpos}=1;

    my ($var_case,$var_control);
    my $Allele_info;
    my $refbase=substr $refseq, $refpos-1, 1;

    $Allele_info=$cm_case->GetAlleleInfo($refseq,$f_qual_case,$refpos,$Min_Reads_case);
    $var_case=VariantCall($Allele_info,$Min_Reads_case,$floor_ratio_case,$Pvalue_Thresh,$floor_indel_size);
    if($var_case->{Pvalue}<$Pvalue_Thresh){  #case is var
      $Allele_info=$cm_control->GetAlleleInfo($refseq,$f_qual_control,$refpos,$Min_Reads_control);
      $var_control=VariantCall($Allele_info,$Min_Reads_control,$floor_ratio_control,$Pvalue_Thresh,$floor_indel_size);

      my $var;
      $var->{wt}=$refbase;
      $var->{case}=$var_case;

      if($var_control->{Pvalue}<$Pvalue_Thresh){  #control is variant
	$var->{status}='germline';
	$var->{control}=$var_control;
      }
      else{  #control is not variant
	if($var_control->{total_readcount}>$Min_Reads_control){  #control has sufficient coverage
	  $var->{status}='somatic';
	}
	else{  #control does not have sufficient coverage
	  $var->{status}='putative_somatic';
	}
      }
      $Vars{$refpos}=$var;
    }
  }

  foreach my $refpos(@DCposes_control){
    next if(defined $Poses{$refpos});
    $Poses{$refpos}=1;

    my ($var_case,$var_control);
    my $Allele_info;
    my $refbase=substr $refseq, $refpos-1, 1;

    $Allele_info=$cm_control->GetAlleleInfo($refseq,$f_qual_control,$refpos,$Min_Reads_control);
    $var_control=VariantCall($Allele_info,$Min_Reads_control,$floor_ratio_control,$Pvalue_Thresh,$floor_indel_size);

    my $var;

    if($var_control->{Pvalue}<$Pvalue_Thresh){  #control is a variant
      $Allele_info=$cm_case->GetAlleleInfo($refseq,$f_qual_case,$refpos,$Min_Reads_case);
      $var_case=VariantCall($Allele_info,1e10,$floor_ratio_case,$Pvalue_Thresh,$floor_indel_size);  #1e10 to skip the FET test

      if($var_case->{total_readcount}>$Min_Reads_case){
	$var->{status}='other';
      }
      else{
	$var->{status}='putative_germline';
      }
      $var->{control}=$var_control;
      $var->{wt}=$refbase;

      $Vars{$refpos}=$var;
    }

  }
  return \%Vars;
}

sub VariantCall{
  my ($Allele_info,$Min_Reads,$floor_ratio,$Pvalue_Thresh,$floor_indel_size)=@_;
  my %var_allele;
  my $wildtype_count=0;
  my $num_total_reads=0;
  my $Pvalue=1;
  foreach my $dc(sort keys %{$Allele_info}){
    foreach my $base(sort keys %{$$Allele_info{$dc}}){
      my $num_total_allele_reads=0;
      my $dPhred_score=0;
      my %uniqRead;
      my %totalreads;
      my @Strands=keys %{$$Allele_info{$dc}{$base}};
      foreach my $ori(@Strands){
	#skip if Max strand score is too small
	#next if($$Allele_info{$dc}{$base}{$ori}{MaxQual}<20);

	$dPhred_score+=$$Allele_info{$dc}{$base}{$ori}{MaxQual};
	my @uniqRpos=keys %{$$Allele_info{$dc}{$base}{$ori}{Rpos}};
	foreach my $rpos(@uniqRpos){
	  $num_total_allele_reads+=$$Allele_info{$dc}{$base}{$ori}{Rpos}{$rpos};
	  $totalreads{$ori}+=$$Allele_info{$dc}{$base}{$ori}{Rpos}{$rpos};
	}
	$uniqRead{$ori}=$#uniqRpos+1;
      }

      if($dc eq 'W'){
	$wildtype_count=$num_total_allele_reads;
      }
      else{
	$var_allele{join(':',$dc,$base)}=$num_total_allele_reads;
      }
      $num_total_reads+=$num_total_allele_reads;
    }
  }

  my $var;
  $var->{total_readcount}=$num_total_reads;
  $var->{wt_readcount}=$wildtype_count;

  if($num_total_reads>=$Min_Reads){
    #Read Count Stats

    my @var_alleles=sort {$var_allele{$b}<=>$var_allele{$a}} keys %var_allele;
    my $notfound=1;
    while($notfound && $#var_alleles>=0){  #only consider biallelic SNPs
      #Fisher Exact
      $var->{var_readcount}=$var_allele{$var_alleles[0]};

      my @abcd;
      push @abcd, $var->{var_readcount};
      push @abcd, $var->{wt_readcount};

      my $exp_var_reads=int($var->{total_readcount}*$floor_ratio);
      my $exp_wt_reads=$var->{total_readcount}-$exp_var_reads;    #biallelic
      push @abcd, $exp_var_reads;
      push @abcd, $exp_wt_reads;

      my $FET=new FET();
      $Pvalue=$FET->Right_Test(@abcd,$Pvalue_Thresh);
      $var->{variant}=$var_alleles[0];

      my ($indelsize)=($var->{variant}=~/[DI]\-*(\d*)/);
      if(defined $indelsize){
	$indelsize=1 if(length($indelsize)<1);
	if($indelsize<$floor_indel_size){
	  $Pvalue=1;
	  shift @var_alleles;  #check the next candidate variant
	}
	else{
	  $notfound=0;   #found a valid variant (indel longer than floor)
	}
      }
      else{
	$notfound=0;  #found a valid variant (SNP)
      }
    }
  }

  $var->{Pvalue}=$Pvalue;

  return $var;
}

sub EstimateMinReads{
  my ($Pvalue_Thresh,$floor_ratio)=@_;
  my $Pvalue=1;
  my $nMinReads=0;
  while($Pvalue>$Pvalue_Thresh){
    $nMinReads+=1;
    my @abcd;
    push @abcd, $nMinReads;
    push @abcd, 0;

#    my $nhalf=int($nMinReads/2);
#    push @abcd,$nMinReads-$nhalf;
#    push @abcd,$nhalf;

    my $nexp=int($nMinReads*$floor_ratio);
    push @abcd, $nexp;
    push @abcd, $nMinReads-$nexp;
    my $FET=new FET();
    $Pvalue=$FET->Right_Test(@abcd);
  }
  return $nMinReads;
}


1;
