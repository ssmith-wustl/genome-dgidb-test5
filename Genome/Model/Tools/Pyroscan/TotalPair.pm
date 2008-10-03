
package Genome::Model::Tools::Pyroscan::TotalPair;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Pyroscan::TotalPair {
    is => 'Command',
    has => [
        dir     => { is => 'Text', doc => '' },
        lst     => { is => 'Text', doc => '' },
    ],
    doc => "?",
};

sub bare_shell_arguments {
    return qw/dir lst/;
}

sub execute {
    my $self = shift;
    my ($dir,$lst)= ($self->dir, $self->lst);
    
    opendir(DIR,$dir);
    my @stats=grep {/\.tumor\.stat/} readdir(DIR);
    my %genelist;
    foreach my $file(@stats){
      my ($gene)=($file=~/^(\S+)\.tumor/);
      $genelist{$gene}=1;
    }
    my @genes=keys %genelist;
    my %hitlist;
    my %prelist;
    my %mutlist;
    my $ngene=0;
    foreach my $gene(@genes){
      my $f_tumor=$gene.'.tumor.stat';
      open(STAT,"<$dir/$f_tumor") || die "unable to open $dir/$f_tumor\n";;
      while(<STAT>){
        chomp;
        my ($type,$g,$pos,@extra)=split /\s+/;
        if($type eq 'Mut'){
          $hitlist{$g}{$pos}=1;
          $mutlist{$g}{$pos}=1;
          $prelist{$g}{$pos}=1;
        }
        elsif($type eq 'FP'){
          $prelist{$g}{$pos}=1;
        }
        elsif($type eq 'MISS'){
          $mutlist{$g}{$pos}=1;
        }
        elsif($type eq 'dbSNP'){
          $hitlist{$g}{$pos}=1;
          $mutlist{$g}{$pos}=1;
          $prelist{$g}{$pos}=1;
        }
        else{}
      }
      close(STAT);

      my $f_normal=$gene.'.normal.stat';
      open(STAT,"<$dir/$f_normal") || die "unable to open $dir/$f_normal\n";;
      while(<STAT>){
        chomp;
        my ($type,$g,$pos,@extra)=split /\s+/;
        if($type eq 'FP'){
          #The following line changes the evaluation metric
          #$hitlist{$g}{$pos}=1; $mutlist{$g}{$pos}=1; $prelist{$g}{$pos}=1;
        }
      }
      close(STAT);


      $ngene++;
    }

    my $nhit_total=0;
    my $nmut_total=0;
    my $npr_total=0;

    foreach my $g(keys %hitlist){
      foreach my $pos(keys %{$hitlist{$g}}){
        $nhit_total++ if($hitlist{$g}{$pos}>0);
      }
    }

    foreach my $g(keys %mutlist){
      foreach my $pos(keys %{$mutlist{$g}}){
        $nmut_total++ if($mutlist{$g}{$pos}>0);
      }
    }

    foreach my $g(keys %prelist){
      foreach my $pos(keys %{$prelist{$g}}){
        $npr_total++ if($prelist{$g}{$pos}>0);
      }
    }


    #printf "%d genes, sen: %d\/%d (%.2f%%), spe: %d\/%d (%.2f%%)\n", $ngene,$nhit_total,$nmut_total,$nhit_total*100/$nmut_total, $nhit_total,$npr_total, $nhit_total*100/$npr_total;
    #printf "%d\t%.2f\t%.2f\n", $ngene,$nhit_total*100/$nmut_total, $nhit_total*100/$npr_total;
    printf "%.2f\t%.2f\n", $nhit_total*100/$nmut_total, $nhit_total*100/$npr_total;
}

1;

