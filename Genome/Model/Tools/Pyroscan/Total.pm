#!/gsc/bin/perl
package Genome::Model::Tools::Pyroscan::Total;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Pyroscan::Total {
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
    
    my @stats;
    if(defined $lst){
      open(LST,"<$lst") || die "unable to open $lst\n";
      while(<LST>){
        chomp;
        my ($gene,@extra)=split /\s+/;
        push @stats,$gene . '.stat';
      }
      close(LST);
    }
    else{
      opendir(DIR,$dir);
      @stats=grep {/\.stat/} readdir(DIR);
    }

    my $nhit_total=0;
    my $nhit2_total=0;
    my $nmut_total=0;
    my $npr_total=0;

    my $ngene=0;

    foreach my $stat(@stats){
      my $line=`grep sen $dir/$stat`;
      next if(!defined $line);
      my ($nhit,$nmut,$nhit2,$npr)=($line=~/sen\: (\d+)\/(\d+)\(.+\sspe\: (\d+)\/(\d+)/);
      next if(!defined $nhit);

      $nhit_total+=$nhit;
      $nmut_total+=$nmut;
      $nhit2_total+=$nhit2;
      $npr_total+=$npr;
      $ngene++;
    }
    $dir=~s/.+\///;
    printf "%s, %d genes, sen: %d\/%d (%.2f%%), spe: %d\/%d (%.2f%%)\n", $dir,$ngene,$nhit_total,$nmut_total,$nhit_total*100/$nmut_total, $nhit2_total,$npr_total, $nhit2_total*100/$npr_total;
    #printf "%s\t%d\/%d\t%.2f\t%d\/%d\t%.2f\n",$dir,$nhit_total,$nmut_total,$nhit_total*100/$nmut_total,$nhit2_total,$npr_total,$nhit2_total*100/$npr_total;
}

1;

