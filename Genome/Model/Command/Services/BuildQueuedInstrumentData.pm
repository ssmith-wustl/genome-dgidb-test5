package Genome::Model::Command::Services::BuildQueuedInstrumentData;

use strict;
use warnings;

use Genome;
use Genome::RunChunk;

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
    'Find all QueueInstrumentDataForGenomeModeling PSEs, create appropriate models, AddReads, and finally trigger Build on the model'
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

    $DB::single = $DB::stopper;

    my $ps = GSC::ProcessStep->get(process_to => 'queue instrument data for genome modeling');
    my @pses = GSC::PSE->get(
                             ps_id => $ps->ps_id,
                             pse_status => 'inprogress',
                         );
    my %model_ids;
    foreach my $pse (@pses) {
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

        my $pp = Genome::ProcessingProfile->get(name => $processing_profile_name);
        unless ($pp) {
            $self->error_message("Failed to get processing profile '$processing_profile_name' for inprogress pse ". $pse->pse_id);
            next;
        }
        my $model = Genome::Model->get(
                                        subject_name => $subject_name,
                                        processing_profile_id => $pp->id,
                                    );
        unless ($model) {
            my $model_name = $subject_name .'.'. $pp->name;
            my $model_create = Genome::Model::Command::Create::Model->create(
                                                                             model_name => $model_name,
                                                                             subject_name => $subject_name,
                                                                             processing_profile_name => $pp->name,
                                                                             bare_args => [],
                                                                         );
            unless ($model_create->execute) {
                $self->error_message("Failed to create model '$model_name'");
                next;
            }
        }
        $model = Genome::Model->get(
                                    subject_name => $subject_name,
                                    processing_profile_id => $pp->id,
                                );
        my @existing_read_sets = Genome::Model::ReadSet->get(
                                                             read_set_id => $instrument_data_id,
                                                             model_id => $model->id,
                                                         );
        if (@existing_read_sets) {
            $self->status_message('Existing read set found for model '. $model->id .' and read set '. $instrument_data_id);
            next;
        }
        unless ($model->isa('Genome::Model::PolyphredPolyscan') || $model->isa('Genome::Model::CombineVariants')){
            my $add_reads = Genome::Model::Command::AddReads->create(
                read_set_id => $instrument_data_id,
                model_id => $model->id,
            );
            unless ($add_reads->execute) {
                $self->error_message('Failed to execute add reads for model '. $model->id .' and read set '. $instrument_data_id);
                next;
            }
        }
        # Add model to list of models to build
        $model_ids{$model->id} = 1;
    }
    #Execute all the builds for models with new data
    for my $model_id (keys %model_ids) {
        my $build = Genome::Model::Command::Build->create(
            model_id => $model_id,
        );
        unless ($build->execute) {
            $self->error_message('Failed to execute build '. $build->id .' for model '. $model_id);
            next;
        }
    }
    return 1;
}



1;
