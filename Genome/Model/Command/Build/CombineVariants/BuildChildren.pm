package Genome::Model::Command::Build::CombineVariants::BuildChildren;

use strict;
use warnings;
use Genome;

class Genome::Model::Command::Build::CombineVariants::BuildChildren{
    is => 'Genome::Model::Event',
};


sub execute{
    my $self = shift;

    my $model = $self->model;
    my @child_models = $model->child_models;

    my %builds;

    my $total_child_builds;
    for my $child (@child_models){
        $self->status_message("Building ".$child->name);
        
        my $build_event = Genome::Model::Command::Build->create(
            model_id => $child->id,
        );
        unless ($build_event){
            $self->error_message("no build object created");;
            return;
        }
        unless ($build_event->execute){
            $self->error_message("Couldn't execute build ".$build_event->id );
            return;
        }
        $total_child_builds++;
        my $build_id = $build_event->build_id;
        my @build_events = Genome::Model::Event->get(build_id => $build_id);
        $builds{$build_id} = [map {$_->id} @build_events];
    }

    my %builds_succeeded;
    my %builds_failed;
    while (1){  #wait until child builds succeed or fail
        sleep 10;
        
        for my $build_id (keys %builds){

            my @event_ids = @{$builds{$build_id}};
            my @statuses = map {`perl -e 'use Genome; my \$build = Genome::Model::Event->get($_); print \$build->event_status;'`} @event_ids;  #btw, this is a hack around the fact that load() doesn't refresh from the datasource, use that here when it is fixed
            unless (@statuses == @event_ids){
                $self->error_message("Didn't get a status for each child build event!");
            }
            my @crashes = grep { $_ =~ /Crashed|Failed/} @statuses;
            my @successes = grep { $_ eq 'Succeeded'} @statuses;
            
            if (@crashes){
                
                $builds_failed{$build_id}++;
                delete $builds{$build_id};
                for my $id (@event_ids){
                    my $event = Genome::Model::Event->get($id);
                    $event->event_status('Crashed');
                }
            
            }elsif(@successes == @statuses){
                $builds_succeeded{$build_id}++;
                delete $builds{$build_id};
            }
        }
        
        unless (keys %builds){  
            if (keys %builds_failed){
                $self->error_message("The following builds failed:".join(" ",keys %builds_failed));
                return;
            }elsif(keys %builds_succeeded == $total_child_builds){
                $self->status_message("All builds succeeded!");
                last;
            }else{
                $self->error_message("unhandled error");
                return;
            }
        }
    }

    return 1;
}

1;
