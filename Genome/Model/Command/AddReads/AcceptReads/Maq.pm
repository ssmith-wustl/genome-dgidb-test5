package Genome::Model::Command::AddReads::AcceptReads::Maq;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;
use File::Temp;

class Genome::Model::Command::AddReads::AcceptReads::Maq {
    is => ['Genome::Model::Event', 'Genome::Model::Command::MaqSubclasser'],
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
    my $maq_pathname = $self->proper_maq_pathname('read_aligner_name');

    $DB::single = 1;
    
    # ensure the reference sequence exists.
    my $lane = $self->run->limit_regions;
    unless ($lane) {
        $self->error_message("No limit regions parameter on run_id ".$self->run_id);
        return;
    }

    my $lane_mapfile;
    if ($self->model->multi_read_fragment_strategy() eq 'EliminateAllDuplicates'  and
        -f $self->unique_alignment_file_for_lane) { 
        # The whole-lane .map file is still around, and we only need the unique reads file anyway
        $lane_mapfile = $self->unique_alignment_file_for_lane;

    } else {
        # We need to build a new map file from 2 or more smaller files
        $lane_mapfile = sprintf("/tmp/AcceptReads_%s_%s.map", $self->run_id, $self->genome_model_event_id);
        my @input_mapfiles;

        # We're always interested in the unique reads, right?
        if (-f $self->unique_alignment_file_for_lane) {
            push @input_mapfiles, $self->unique_alignment_file_for_lane;
        } else {
            push @input_mapfiles, glob($self->alignment_submaps_dir_for_lane . '/*unique.map');
        }
                
        if ($self->model->multi_read_fragment_strategy() ne 'EliminateAllDuplicates') {
            # Include duplicate reads, too?
            if (-f $self->unique_alignment_file_for_lane) {
                push @input_mapfiles, $self->duplicate_alignment_file_for_lane;
            } else {
                push @input_mapfiles, glob($self->alignment_submaps_dir_for_lane . '/*duplicate.map');
            }
        }

        system($maq_pathname, 'mapmerge', $lane_mapfile, @input_mapfiles);
    }
        
    unless (-f $lane_mapfile) {
        $self->error_message("map file for lane $lane does not exist $lane_mapfile");
        return;
    }

    my $line=`/gscmnt/sata114/info/medseq/pkg/maq/branches/lh3/maq-xp/maq-xp pileup -t $lane_mapfile 2>&1`;
    my ($evenness)=($line=~/(\S+)\%$/);
    if($evenness > $model->align_dist_threshold) {
        # The align-reads step make submap files for each chromosome.  We can delete this one now
        unlink $lane_mapfile;
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

