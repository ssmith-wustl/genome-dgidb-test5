package Genome::Model::SomaticValidation::Command::UpdateSamples;

use strict;
use warnings;

use Genome;
use Command; 
use Data::Dumper;

class Genome::Model::SomaticValidation::Command::UpdateSamples {
    is => 'UR::Object::Command::List',
    has => [
        models => { is => 'Genome::Model::SomaticValidation', is_many => 1,
                    doc => 'the models to update', }
    ],
    doc => 'switch the sample on a model to an equivalent sample based on available instrument data (and eventually pending workorders)',
};

sub help_synopsis {
    return <<EOS;

# one model
genome model somatic-validation update-samples 12345

# all models using a given set of capture probes
genome model somatic-validation update-samples model_groups.name="AMLx150 Validation (RT#78086)"

# all models in a given group
genome model somatic-validation update-samples target_region_set_name="AML_KP - OID36117 capture chip set"

EOS
}

sub execute {
    my $self = shift;
    my @models;
    for my $model (@models) {
        my $tumor_sample = $model->tumor_sample;
        my $normal_sample = $model->normal_sample;

        my $patient = $tumor_sample->patient();
        unless ($patient == $normal_sample->patient()) {
            die "patients do not match for tumor and normal on model " . $model->__display_name__;
        }

        my @patient_instdata = Genome::InstrumentData::Solexa->get(
            target_region_set_name => $model->target_region_set_name,
            'sample.patient.id' => $patient->id,
        );

        unless (@patient_instdata) {
            $self->status_message("No instrument data for patient " . $patient->__display_name__ . " on the target set yet.  Cannot update the model until we have logic to check the workorder");
            next;
        }

        my @instdata_tumor;
        my @instdata_normal;
        my @instdata_unknown;
        for my $instdata (@patient_instdata) {
            if ($instdata->sample == $tumor_sample) {
                push @instdata_tumor, $instdata,
            }
            elsif ($instdata->sample == $normal_sample) {
                push @instdata_normal, $instdata;
            }
            else {
                push @instdata_unknown, $instdata;
            }
        }

        if (@instdata_tumor and @instdata_normal) {
            $self->status_message("Some data found for both samples.  Any other instata may be for other models.");
            next;
        }

        if (@instdata_tumor == 0) {
            my %tumor_equiv_samples = map { $_->id => $_ } Genome::Sample->get(
                source => $patient,
                common_name => $tumor_sample->common_name,
                tissue_label => $tumor_sample->tissue_label,
                tissue_desc => $tumor_sample->tissue_desc,
            );
        
            if (%tumor_equiv_samples) {
                my @has_instdata = grep { $tumor_equiv_samples{$_->id} } @instdata_unknown;
                if (@has_instdata == 0) {
                    $self->status_message("unknown instrument data in are not suitable swaps for the tumor");
                }
                else {
                    my %sample_ids = map { $_->sample_id => 1 } @has_instdata;
                    if (keys(%sample_ids) > 1) {
                        $self->status_message("ambiguous replacement instdata for the tumor");
                    }
                    else {
                        # TODO: switch to this sample for the tumor_sample on this model
                        # probably add the instrument data too
                    }
                }
            }
            else {
                $self->status_message("No equivalent tumor data found for model " . $model->__display_name__);
            }
        }
    
        # TODO: repeat the above for the normal model

    }

    return 1;
}

1;

