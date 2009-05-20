package Genome::Model::Command::Services::BuildQueuedInstrumentData;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Services::BuildQueuedInstrumentData {
    is => 'Command',
    has => [
        test => {
            is => 'String',
            doc => "This parameter, if set true, will only process pses with negative id's, allowing your test to complete in a reasonable time frame.",
            is_optional => 1,
            default => 0,
        }
    ],
};


sub help_brief {
    'Find all QueueInstrumentDataForGenomeModeling PSEs, create appropriate models, assign instrument data, and finally trigger Build on the model'
}

sub help_synopsis {
    return <<'EOS'
EOS
}

sub help_detail {
    return <<EOS
EOS
}

sub execute {
    my $self = shift;

    my $ps = GSC::ProcessStep->get(process_to => 'queue instrument data for genome modeling');
    my @pses = GSC::PSE->get(
                             ps_id => $ps->ps_id,
                             pse_status => 'inprogress',
                         );
    my %model_ids;
    PSE: foreach my $pse (@pses) {
        if ($self->test){
            next if $pse->id > 0;
        }
        my ($instrument_data_type)      = $pse->added_param('instrument_data_type');
        my ($instrument_data_id)        = $pse->added_param('instrument_data_id');
        my ($subject_type)              = $pse->added_param('subject_type');
        my ($subject_name)              = $pse->added_param('subject_name');
        my ($sample_name)               = $pse->added_param('sample_name');
        my ($library_name)              = $pse->added_param('library_name');
        my ($research_project_name)     = $pse->added_param('research_project_name');
        my ($processing_profile_name)   = $pse->added_param('processing_profile_name');

        unless ($instrument_data_type =~ /sanger/i) { next PSE; }

        if ($instrument_data_type =~ /sanger/i) {

            my $pse      = GSC::PSE::AnalyzeTraces->get($instrument_data_id);

            unless (defined($pse)) {
                $self->error_message("failed to fetch pse for sanger instrument data with id '$instrument_data_id'");
                next PSE;
            }
            
            my $run_name = $pse->run_name();
            
            unless (defined($run_name)) {
                $self->error_message("failed to get a run_name for sanger instrument data with id '$instrument_data_id'");
                next PSE;
            }                                                                     
       
            $instrument_data_id = $run_name;

        } 
        
        my $pp = Genome::ProcessingProfile->get(name => $processing_profile_name);
        unless ($pp) {
            $self->error_message("Failed to get processing profile '$processing_profile_name' for inprogress pse ". $pse->pse_id);
            next PSE;
        }

        my $model = Genome::Model->get(
                                        subject_name => $subject_name,
                                        processing_profile_id => $pp->id,
                                    );

        unless ($model) {
        
            my $model_name = $subject_name .'.'. $pp->name;
            
            my $model = Genome::Model->create(
                                              name                  => $model_name,
                                              subject_name          => $subject_name,
                                              subject_type          => $subject_type,
                                              processing_profile    => $pp,
                                              auto_assign_inst_data => 1,
                                             );
                                                  
            unless (defined($model)) {
                $self->error_message("Failed to create model '$model_name'");
                next;
            }
            
        }
        
        $model = Genome::Model->get(
                                    subject_name => $subject_name,
                                    processing_profile_id => $pp->id,
                                );

        unless ($model->auto_assign_inst_data() == 1) { next PSE; }
        
        my @existing_instrument_data = Genome::Model::InstrumentDataAssignment->get(
                                                                                    instrument_data_id => $instrument_data_id,
                                                                                    model_id => $model->id,
                                                                                 );
        if (@existing_instrument_data) {
            $self->status_message('Existing instrument_data found for model '. $model->id .' and instrument_data_id '. $instrument_data_id);
            next;
        }
        unless ($model->isa('Genome::Model::PolyphredPolyscan') || $model->isa('Genome::Model::CombineVariants')){
            my $assign = Genome::Model::Command::InstrumentData::Assign->create(
                instrument_data_id => $instrument_data_id,
                model_id => $model->id,
            );
            unless ($assign->execute) {
                $self->error_message('Failed to execute instrument-data assign for model '. $model->id .' and instrument data '. $instrument_data_id);
                next;
            }
        }
        # Add model to list of models to build
        $model_ids{$model->id} = 1;

        # Set the pse as completed since this is the end of the line for the pses
        $pse->pse_status("completed");
    }
    #Execute all the builds for models with new data
    for my $model_id (keys %model_ids) {
        my $build = Genome::Model::Command::Build::PolyphredPolyscan->create(
            model_id => $model_id,
        );
        unless ($build->execute) {
            $self->error_message('Failed to execute build '. $build->id .' for model '. $model_id);
            next;
        }
    }

    # Now, build all of the parent models of these models
    my @composite_members = keys %model_ids;
    my %parent_model_ids;

    # For each child model, find its parent and mark the parent to be built in the hash
    for my $child_model_id (@composite_members) {
        my @model_links = Genome::Model::CompositeMember->get(member_id => $child_model_id);

        # For each parent of this model, mark that parent to be built
        for my $model_link (@model_links) {
            $parent_model_ids{$model_link->composite_id} = 1;
        }
    }

    # Now grab all parent models which have been marked for building from the hash
    my @parent_models;
    for my $model_id_to_build (keys %parent_model_ids) {
        my $parent_model = Genome::Model->get($model_id_to_build);

        unless ($parent_model) {
            $self->error_message("Failed to get parent model for id $model_id_to_build");
            die;
        }
        push @parent_models, $parent_model;
    }
 
    for my $model (@parent_models) {
        my $build = Genome::Model::Command::Build::CombineVariants->create(
            model_id => $model->id,
        );
        unless ($build->execute) {
            $self->error_message('Failed to execute build '. $build->id .' for model '. $model->id);
            next;
        }
    }
    
    return 1;
}



1;
