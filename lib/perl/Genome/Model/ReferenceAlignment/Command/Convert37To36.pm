package Genome::Model::ReferenceAlignment::Command::Convert37To36;
use strict;
use warnings;

class Genome::Model::ReferenceAlignment::Command::Convert37To36 {
    is => 'Genome::Command::Base',
    has_input => [
        models => {
            is => 'Genome::Model',
            is_many => 1,
            shell_args_position => 1,
            doc => 'use these build37 models',
        },
    ],
    doc => 'Copy models based on build37 to new ones based on build36',
};

sub help_brief {
    'Copy models based on build37 to new ones based on build36'
}

sub help_detail {
    help_brief()
}

sub help_synopsis {
    help_brief()
}

sub execute {
    my $self = shift;
    my @build37_model_ids;
    my %roi37to36 = reverse Genome::Model::Command::Services::AssignQueuedInstrumentData->get_build36_to_37_rois();
    for my $model ($self->models) {
        my $result = Genome::Model::Command::Copy->execute(
            model => $model,
            overrides => [
                "name=" . $model->name . ".36",
                'reference_sequence_build=101947881', #Build 36 itself
                'dbsnp_build=106227442',
                'annotation_reference_build=113115679',#Model/ImportedAnnotation.pm for build36
            ],
        );
        map{$_->delete}grep{$_->name eq 'genotype_microarray'}$result->_new_model->inputs;
        if(exists $roi37to36{$model->region_of_interest_set_name}) {
            print $model->id . " updating region of interest set name to " . $roi37to36{$model->region_of_interest_set_name} . "\n";
            $model->region_of_interest_set_name($roi37to36{$model->region_of_interest_set_name});
        }
        $model->build_requested(1);
        push @build37_model_ids, $result->_new_model->id;
    }
    print join(',',@build37_model_ids) . "\n";
    return 1;
}
