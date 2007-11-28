package Genome::Model::Command::AddReads::MergeAlignments::Maq;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;
use File::Path;
use File::Basename;
use Data::Dumper;
use Date::Calc;
use File::stat;

use App::Lock;

class Genome::Model::Command::AddReads::MergeAlignments::Maq {
    is => 'Genome::Model::Event',
    has => [ 
        ref_seq_id   => { is => 'Integer', is_optional => 0, doc => 'the refseq on which to operate' },
    ]
};

sub help_brief {
    "Use maq to align reads";
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads postprocess-alignments merge-alignments maq --model-id 5 --run-id 10
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
    my $model_data_directory = $model->data_directory;

    $DB::single = 1;

    my $lanes;
    
    my $now = App::Time->now();


    # find when the last merge happened
    my ($last_merge_event) = Genome::Model::Event->get(sql=>sprintf("select * from GENOME_MODEL_EVENT where event_type='genome-model add-reads merge-alignments maq'
                                                       and event_status='Succeeded' and model_id=%s and ref_seq_id='%s' order by date_completed DESC",
                                                       $model->id, $self->ref_seq_id));
    
    # find the runs which have been accepted since the last merge (or since "ever" if there was no merge)                           
    my $last_merge_done_str = (defined $last_merge_event ? sprintf("and date_completed >= '%s'",
                                                                   $last_merge_event->date_completed)
                                                         : "");
    my @run_events = Genome::Model::Event->get(sql=>sprintf("select * from GENOME_MODEL_EVENT where event_type='genome-model add-reads accept-reads maq'
                                                %s and model_id=%s and event_status='Succeeded'",
                                                $last_merge_done_str,
                                                $model->id));
    my @run_ids = map {$_->run_id} @run_events; 
    my @target_runs = Genome::RunChunk->get(id=>\@run_ids);
    
    my @input_alignments;
    
    foreach my $in_run (@target_runs) {
        my $resolved_input =  $self->resolve_input_alignments_filename_from_run(run=>$in_run);        
        push @input_alignments, $resolved_input if (-f $resolved_input);
    }
    if (@input_alignments) {
    
        my $accumulated_alignments_filename = $model->resolve_accumulated_alignments_filename(ref_seq_id=>$self->ref_seq_id);
        my $align_dir = dirname($accumulated_alignments_filename);
        unless (-d $align_dir) {
            mkdir($align_dir);
        }
        
        my $accum_tmp = $accumulated_alignments_filename . "." . $$;

        my $basename = basename($accumulated_alignments_filename);

        unless ($model->lock_resource(resource_id=>"alignments.submap/$basename")) {
            $self->error_message("Can't get lock for master accumulated alignment");
            return undef;
        }
    
        # the master alignment file that we're merging into is an input, too!
        my @accum_input; 
        if (-e $accumulated_alignments_filename) {
            unshift @input_alignments, $accumulated_alignments_filename;
        }

        my @cmdline = (qw/maq mapmerge/, $accum_tmp, @input_alignments);
        my $rv = system(@cmdline);
        if ($rv) {
            $self->error_message("exit code from maq merge was nonzero; something went wrong.  command line was " . join " ", @cmdline);
            return;
        }
    
        rename($accum_tmp, $accumulated_alignments_filename);
    } else {
        $self->status_message("Nothing to do!");
    }
    
    return 1;
}


sub resolve_input_alignments_filename_from_run {
    my $self = shift;
    my %p = @_;
    
    my $run = $p{run};
    
    my $model = Genome::Model->get(id => $self->model_id);
    my $model_data_directory = $model->data_directory;
    
    my @subsequences = grep {$_ ne "all_sequences" } $model->get_subreference_names(reference_extension=>'bfa');
    
    if (@subsequences && !$self->ref_seq_id) {
        $self->error_message("there are multiple subsequences available, but you did not specify a refseq");
        return;
    }
      
    my $base_run_path = sprintf("%s/runs/%s/%s/alignments_lane_%s",
                               $model_data_directory,
                               $run->sequencing_platform,
                               $run->name,
                               $run->limit_regions);
    
    if (@subsequences) {
        return $base_run_path . ".submaps/" . $self->ref_seq_id . ".map";
    } else {
        return $base_run_path;
    }
}

1;

