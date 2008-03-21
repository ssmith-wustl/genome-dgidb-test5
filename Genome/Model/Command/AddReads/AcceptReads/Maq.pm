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

class Genome::Model::Command::AddReads::AcceptReads::Maq {
    is => 'Genome::Model::Event',
    has => [
        model_id   => { is => 'Integer', is_optional => 0, doc => 'the genome model on which to operate' },
        run_id => { is => 'Integer', is_optional => 0, doc => 'the genome_model_run on which to operate' },
    ],
};

sub help_brief {
    "Use maq to accept reads from a lane if the evenness is greater than the model's alignment_distribution_threshold";
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

sub should_bsub {1;}

sub execute {
    my $self = shift;
    
    my $model = Genome::Model->get(id => $self->model_id);

    my $lanes;
    
    $DB::single = 1;
    
    # ensure the reference sequence exists.
    my $run_path=$self->resolve_run_directory();
    my $lane = $self->run->limit_regions;
    unless ($lane) {
        $self->error_message("No limit regions parameter on run_id ".$self->run_id);
        return;
    }

    my @goodlanes;
    
    #my $lane_mapfile=$run_path . '/'. 'alignments_lane_'.$lane;
    my $lane_mapfile=$self->alignment_file_for_lane();
    my $line=`/gscmnt/sata114/info/medseq/pkg/maq/branches/lh3/maq-xp/maq-xp pileup -t $lane_mapfile 2>&1`;
    my ($evenness)=($line=~/(\S+)\%$/);
    if($evenness > $model->alignment_distribution_threshold) {
        return 1;
    } else {
        $self->error_message("Run id ".$self->run_id." failed accept reads.  Evenness $evenness is lower than the threshold ".$model->alignment_distribution_threshold);
        return 0;
    }
}

sub bsub_rusage {
    return "-R 'select[type=LINUX64]'";

}


1;

