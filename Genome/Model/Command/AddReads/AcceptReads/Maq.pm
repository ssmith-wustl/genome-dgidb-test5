package Genome::Model::Command::AddReads::AcceptReads::Maq;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;
use File::Path;
use Data::Dumper;
use Date::Calc;
use File::stat;

use App::Lock;

class Genome::Model::Command::AddReads::AcceptReads::Maq {
    is => 'Genome::Model::Event',
    has => [ 
        model_id   => { is => 'Integer', is_optional => 0, doc => 'the genome model on which to operate' },
    ]
};

sub help_brief {
    "Use maq to accept reads";
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads accept-reads maq --model-id 5 --run-id 10
EOS
}

sub help_detail {                           
    return <<EOS 
This command is usually called as part of the add-reads process
EOS
}

sub execute {
    my $self = shift;
    
    my $model = Genome::Model->get(id => $self->model_id);

    my $lanes;
    
    # ensure the reference sequence exists.
    my $run_path=$self->resolve_run_directory();
    $lanes=$self->run->limit_regions || '1245678';
    my @goodlanes;
    foreach my $lane (split //, $lanes){
      my $lane_mapfile=$run_path . '/'. 'alignments_lane_'.$lane;
      my $line=`/gscmnt/sata114/info/medseq/pkg/maq/branches/lh3/maq-xp/maq-xp pileup -t $lane_mapfile 2>&1`;
      my ($evenness)=($line=~/(\S+)\%$/);
      if($evenness > $model->alignment_distribution_threshold){
	push @goodlanes, $lane;
      }
    }
    unless {@goodlanes) {return 0;}
    $self->run->limit_regions{join('',@goodlanes)};
    return 1;
}


1;

