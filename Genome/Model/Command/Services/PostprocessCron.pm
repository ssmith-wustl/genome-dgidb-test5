package Genome::Model::Command::Services::PostprocessCron;

use strict;
use warnings;

use Genome;
use Command;

use GSC;
use IO::File;
use File::Basename;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',                       
);

sub help_brief {
    return <<EOS
calls genome-model add-reads postprocess-alignments if necessary 
EOS
}

sub help_synopsis {                         # Replace the text below with real examples <---
    return <<EOS
genome-model tools postprocess-cron --model-id 1
EOS
}

sub help_detail {                           # This is what the user will see with the longer version of help. <---
    return <<EOS 
Determines whether a model has un-merged & unprocessed alignments, and if so, kicks off the
"postprocess-alignments" command on the model.  The postprocess step will merge alignments, update genotype probabilities,
write genotypes, and upload them to the medseq database.
EOS
}

sub execute {
    my $self = shift;
    
    my @pp_models = grep {$self->model_requires_postprocess($_)} Genome::Model->get();

    foreach my $model (@pp_models) {
        Genome::Model::Command::Build::ReferenceAlignment->execute(model_id=>$model->id);
    }
}

sub model_requires_postprocess {
    my $self = shift;
    my $model = shift;

        # find when the last merge happened
    my ($last_merge_event) = Genome::Model::Event->get(sql=>sprintf("select * from GENOME_MODEL_EVENT where event_type = 'genome-model add-reads postprocess-alignments'
                                                       and event_status='Succeeded' and model_id=%s order by date_completed DESC",
                                                       $model->id));
    
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

    return (@target_runs > 0);
    
}
