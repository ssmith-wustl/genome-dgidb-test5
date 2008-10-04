package Genome::Model::Tools::Pyroscan::Run;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Pyroscan::Run {
    is => 'Command',
    has => [
        refseq  => { is => 'Text',   doc => 'reference sequence'  },
        qt      => { is => 'Text',   doc => '.qual files for the tumor reads'  },
        cmt     => { is => 'Text',   doc => 'cross-match alignment for the tumor reads'  },
    ],
    has_optional => [
        qn      => { is => 'Text',   doc => '.qual files for the normal reads'  },
        cmn     => { is => 'Text',   doc => 'cross-match alignment for the normal reads'  },    
        pvalue  => { is => 'Text',   doc => 'P value stringency', default_value => 1e-6  },
        rt      => { is => 'Text',   doc => 'baseline variant/wildtype read ratio in tumor', default_value => 0 },
        rn      => { is => 'Text',   doc => 'baseline variant/wildtype read ratio in normal', default_value => 0 },
        indel   => { is => 'Number', doc => 'minimum indel size to report', default_value => 3  },
        lstpos  => { is => 'Text',   doc => 'list of positions for genotyping'  },
        gs      => { is => 'Boolean',doc => 'output in genotype-submission format' },
        sn      => { is => 'Text',   doc => 'sample name'  },
    ],
    doc => "SNP and small indel detection using Fisher's Exact Test",
};

use Genome::Model::Tools::Pyroscan::Detector;
use Genome::Model::Tools::Pyroscan::CrossMatch;
use Bio::SeqIO;
use Getopt::Long;
use Pod::Usage;

sub sub_command_sort_position {
    # this should always be first in the list of commands under Pyroscan...
    -1
}

sub help_detail {
    return <<EOS; 
Variant (SNPs and small indels) detection from 454 amplicon/capture data using Fisher's Exact Test

Report bugs to <kchen\@watson.wustl.edu>.
EOS
}

sub execute {
    my $self = shift;
    
    my $fa_refseq               = $self->refseq;
    my $f_case_qual             = $self->qt;
    my $f_cm_case               = $self->cmt;
    
    my $f_control_qual          = $self->qn;
    my $f_cm_control            = $self->cmn;

    my $Pvalue                  = $self->pvalue;
    my $floor_ratio_case        = $self->rt;
    my $floor_ratio_control     = $self->rn;
    my $floor_indel_size        = $self->indel;
    my $f_poslst                = $self->lstpos;
    
    my $o_genotype_submission   = $self->gs;
    my $samplename              = $self->sn;
    
    my $version='1.0';
    
=cut
    
    my $status=&GetOptions(
                           "refseq=s" => \$fa_refseq,  # reference sequence
                           "qt=s" => \$f_case_qual,    # .qual files for the case reads
                           "cmt=s"   => \$f_cm_case,      # cross-match alignment for the case reads
                           "qn=s" => \$f_control_qual,   # .qual files for the control reads
                           "cmn=s" => \$f_cm_control,  # cross-match alignment for the control reads
                           "pvalue=s" => \$Pvalue, # P value stringency
                           "rt=s"  => \$floor_ratio_case,  # baseline variant/wildtype read ratio in case
                           "rn=s" => \$floor_ratio_control,  # baseline variant/wildtype read ratio in control
                           "indel=i" => \$floor_indel_size,   # minimum indel size to report
                           "lstpos=s" => \$f_poslst,   #list of positions for genotyping
                           "gs!" => \$o_genotype_submission,   #output in genotype-submission format
                           "sn=s" => \$samplename,
                           "help" => \$help
                          );

=cut

    if(!defined $fa_refseq||!defined $f_case_qual || !defined $f_cm_case){
      die "-refseq, -qt, and -cmt are mandantory, try PyroScan.pl -help for more information\n";
    }

    print "#refseq: $fa_refseq\n" if(defined $fa_refseq);
    print "#case reads quality file: $f_case_qual\n" if(defined $f_case_qual);
    print "#case cross-match alignment file: $f_cm_case\n" if(defined $f_cm_case);
    print "#control reads quality file: $f_control_qual\n" if(defined $f_control_qual);
    print "#control cross-match alignment file: $f_cm_control\n" if(defined $f_cm_control);
    print "#P value cutoff: $Pvalue\n" if(defined $Pvalue);
    print "#baseline variant/wildtype read ratio in case: $floor_ratio_case\n" if(defined $floor_ratio_case);
    print "#baseline variant/wildtype read ratio in control: $floor_ratio_control\n" if(defined $floor_ratio_control);
    print "#only report indels longer than: $floor_indel_size bp\n";

    my $refseq=&getRefSeq($fa_refseq);

    my @poses=&Readlist($f_poslst);

    my $var;
    if(defined $f_cm_control && defined $f_control_qual){  # case/control analysis

      my $case_cm=new Genome::Model::Tools::Pyroscan::CrossMatch(fin=>$f_cm_case);
      my $control_cm=new Genome::Model::Tools::Pyroscan::CrossMatch(fin=>$f_cm_control);

      my $detector=new PyroScan();
      $var=$detector->MutDetect(\@poses,$case_cm,$floor_ratio_case,$f_case_qual,$control_cm,$floor_ratio_control,$f_control_qual,$Pvalue, $floor_indel_size, $refseq);
    }
    else{  # cohort analysis

      my $case_cm=new Genome::Model::Tools::Pyroscan::CrossMatch(fin=>$f_cm_case);
      my $case_detect=new PyroScan();
      $var=$case_detect->VarDetect(\@poses,$case_cm,$floor_ratio_case,$f_case_qual,$Pvalue, $floor_indel_size, $refseq);
    }

    &Output($var,$o_genotype_submission,$samplename,$version);
}

sub Output{
  #output the detected variants
  my ($Vars, $ogs,$samplename,$version)=@_;

  foreach my $pos(sort {$a<=>$b} keys %{$Vars}){
    my $var=$$Vars{$pos};
    my $mut_type=$var->{status};
    my $case=$var->{case};
    my $control=$var->{control};

    if($ogs){   #printout genotype submission file
      if(defined $case){
	if($case->{variant}=~/^D\-(\d+)/){
	  $case->{variant}=join('','-','N'x$1);
	}
	elsif($case->{variant}=~/^I\-(\d+)/){
	  $case->{variant}=join('','+','N'x$1);
	}
	else{
	  $case->{variant}=~s/^S\://;
	}

	$samplename="case" if(!defined $samplename);
	print "B36\tC5\tO+\t";
	printf "%d\t%d\t%s\t\'%s\t\'%s\tPyroScan%s\(%s\:%s\:", $pos,$pos,$samplename,$var->{wt},$case->{variant},$version,$var->{wt},$case->{variant};
	print "$case->{Pvalue}";
	print "\)\t\-"
      }
      if(defined $control){
	if($control->{variant}=~/^D\-(\d+)/){
	  $control->{variant}=join('','-','N'x$1);
	}
	elsif($control->{variant}=~/^I\-(\d+)/){
	  $control->{variant}=join('','+','N'x$1);
	}
	else{
	  $control->{variant}=~s/^S\://;
	}
	$samplename="control" if(!defined $samplename);
	print "B36\tC5\tO+\t";
	printf "%d\t%d\t%s\t\'%s\t\'%s\tPyroScan%s\(%s\:%s\:", $pos,$pos,$samplename,$var->{wt},$control->{variant},$version,$var->{wt},$control->{variant};
	print "$control->{Pvalue}";
	print "\)\t\-",
      }
      print "\n";
    }
    else{
      printf "%d\t", $pos;
      printf "%s\t", $var->{status} if(defined $var->{status});
      if(defined $case){
	my $case_type=($case->{variant}=~/[DI]/)?'INDEL':'SNP';
	my $case_ratio=($case->{wt_readcount}>0)?$case->{var_readcount}/$case->{wt_readcount}:-1;
	printf "%s\t%d\t%s\t%d\t%s\t%d\t%.6f",$case_type,$case->{total_readcount},$var->{wt},$case->{wt_readcount},$case->{variant},$case->{var_readcount},$case_ratio;
	print "\t$case->{Pvalue}";
      }
      if(defined $control){
	my $control_type=($control->{variant}=~/[DI]/)?'INDEL':'SNP';
	my $control_ratio=($control->{wt_readcount}>0)?$control->{var_readcount}/$control->{wt_readcount}:-1;
	printf "\t%s\t%d\t%s\t%d\t%s\t%d\t%.6f",$control_type,$control->{total_readcount},$var->{wt},$control->{wt_readcount},$control->{variant},$control->{var_readcount},$control_ratio;
	print "\t$control->{Pvalue}";
      }
      print "\n";
    }
  }
}

sub Readlist{
  #read in a list of refseq positions for genotyping
  my ($f_poslst)=@_;
  my @pos;
  if(defined $f_poslst){
    open(LST,"<$f_poslst") || die "unable to open $f_poslst\n";
    while(<LST>){
      chomp;
      my @u=split /\s+/;
      push @pos,$u[0];
    }
    close(LST);
  }
  return @pos;
}


sub getRefSeq{
  my ($f_fasta)=@_;
  my $stream = Bio::SeqIO->newFh(-file =>$f_fasta , -format => 'Fasta'); # read from standard input
  my $fasta;
  my $seq = <$stream>;

  return $seq->seq;
}

sub help_usage {

  print STDOUT <<"EOF";
Synopsis: Variant (SNPs and small indels) detection from 454 amplicon/capture data using Fisher's Exact Test

Options:
  -help                  display help information
  -refseq <.fasta>       fasta file of the reference sequence
  -qt <.qual>            quality file of the reads of the case samples
  -cmt <.cm.out>         cross-match alignment for the case reads
  -qn <.qual>            quality file of the reads of the control samples
  -cmn <.cm.out>         cross-match alignment for the control reads
  -pvalue <a P value>    P value cutoff, default=1e-6
  -rt <variant ratio>    floor variant/wildtype read ratio in the cases, default=0
  -rn <variant ratio>    floor variant/wildtype read ratio in the controls, default=0
  -indel <bp>            minimum indel size to report, default=3 bp
  -lstpos <.lst>         a text file, first column lists refseq positions for survey

Report bugs to <kchen\@watson.wustl.edu>.
EOF
}


1;

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


