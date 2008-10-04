package Genome::Model::Tools::Pyroscan::TotalVar;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Pyroscan::TotalVar {
    is => 'Command',
    has => [
        dir     => { is => 'Text', doc => '', shell_args_position => 1 },
        lst     => { is => 'Text', doc => '', shell_args_position => 2 },
    ],
    doc => "?",
};

sub help_detail {
    return <<EOS; 
TODO: write this

Report bugs to <kchen\@watson.wustl.edu>.
EOS
}

sub execute {
    my $self = shift;
    my ($dir,$lst)= ($self->dir, $self->lst);
    
    opendir(DIR,$dir);
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


    my $ngene=0;
    my ($nhit,$nmut,$npre)=(0,0,0);

    foreach my $stat(@stats){

      open(STAT,"<$dir/$stat") || die "unable to open $dir/$stat\n";;
      while(<STAT>){
        chomp;
        my ($pos,$mut_type,$var_type,@extra)=split /\s+/;
        if($mut_type=~/somatic/i){
          if($_=~/Somatic$/i){
            $nhit++;
            $nmut++;
          }
          $npre++;
        }
        elsif($mut_type=~/germline/i || $_=~/dbsnp/i){
          $nhit++;
          $nmut++;
          $npre++;
        }
        else{
          $nmut++ if(/Somatic$/i);
        }
      }
      close(STAT);

      $ngene++;
    }

    $dir=~s/.*\///;
    #printf "%s, %d genes, sen: %d\/%d (%.2f%%), spe: %d\/%d (%.2f%%)\n", $dir,$ngene,$nhit,$nmut,$nhit*100/$nmut,$nhit,$npre,$nhit*100/$npre;
    printf "%d\/%d\t%.2f\t%d\/%d\t%.2f\n",$nhit,$nmut,$nhit*100/$nmut,$nhit,$npre,$nhit*100/$npre;

    #printf "%d\t%.2f\t%.2f\n", $ngene,$nhit_total*100/$nmut_total, $nhit_total*100/$npr_total;
    #printf "%.2f\t%.2f\n", $nhit*100/$nmut, $nhit*100/$npre;

}

1;

