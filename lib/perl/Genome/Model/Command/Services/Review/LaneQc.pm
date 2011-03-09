package Genome::Model::Command::Services::Review::LaneQc;

class Genome::Model::Command::Services::Review::LaneQc {
    is => 'Genome::Command::Base',
    doc => 'make sure lane QC exists for the supplied instrument data',
    has => [
        instrument_data => {
            is => 'Genome::InstrumentData',
            is_many => 1,
            shell_args_position => 1,
            doc => 'instrument data, resolved by Genome::Command::Base', 
        },
        auto_action => {
            is => 'Boolean',
            default => 0,
            doc => 'enable/disable whether automatic action is taken',
        }
    ],
    has_optional => [
        processing_profile => {
            is => 'Genome::ProcessingProfile::ReferenceAlignment',
            doc => 'processing profile for lane QC, defaults to "february 2011 illumina lane qc"',
        },
    ],
};

sub execute {
    my $self = shift;

    my $processing_profile = $self->processing_profile;
    unless ($processing_profile) {
        $processing_profile = Genome::ProcessingProfile->get(name => 'february 2011 illumina lane qc');
        $self->processing_profile($processing_profile);
    }

    my @instrument_data = $self->instrument_data;
    for my $instrument_data (@instrument_data) {
        my $lane_qc_model = $self->confirm_or_create_lane_qc($instrument_data->id);
    }
}

sub confirm_or_create_lane_qc {
    my $self = shift;
    my $instrument_data_id = shift;

    my @inputs = Genome::Model::Input->get(value_id => $instrument_data_id);
    my @inputs_models = map { $_->model } @inputs;
    my ($feb_model) = grep { $_->processing_profile_name eq 'february 2011 illumina lane qc' } @inputs_models;
    if ($feb_model) {
        $self->status_message("$instrument_data_id: already has a lane QC");
        return $feb_model;
    }
    else {
        if ($self->auto_action) {
            $self->status_message("$instrument_data_id: creating a lane QC");
            return $self->create_lane_qc($instrument_data_id);
        }
        else {
            $self->status_message("$instrument_data_id: needs a lane QC");
            return 1;
        }
    }
}

sub create_lane_qc {
    my $self = shift;
    my $instrument_data_id = shift;
    my $instrument_data = Genome::InstrumentData->get($instrument_data_id);
    my $sample = $instrument_data->sample;
    my $subject_name = $sample->name;
    my $subset_name = $instrument_data->subset_name || 'unknown-subset';
    my $run_name = $instrument_data->short_name || 'unknown-run';
    my $model_name = $run_name . '.' . $subset_name . '.prod-qc';

    my $define_cmd = Genome::Model::Command::Define::ReferenceAlignment->create(
        subject_name => $subject_name,
        processing_profile_name => $self->processing_profile->name,
        model_name => $model_name,
    );
    unless ($define_cmd->execute) {
        $self->error_message("Failed to define new lane QC model.");
        return;
    }

    my $lane_qc_model = Genome::Model->get($define_cmd->result_model_id);
    unless ($lane_qc_model) {
        $self->error_message("Failed to retrieve resulting model from lane QC define.");
        return;
    }

    $lane_qc_model->add_instrument_data($instrument_data);
    $lane_qc_model->build_requested(1);
}
