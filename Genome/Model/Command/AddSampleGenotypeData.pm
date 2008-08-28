package Genome::Model::Command::AddSampleGenotypeData;

use strict;
use warnings;

use above "Genome";
use Command; 

class Genome::Model::Command::AddSampleGenotypeData {
    is => 'Command',
    # TODO : should we be a genome model event?
    has => [
        input_data => [is => 'Hashref',
        ],
        technology_type => [is => 'String',
                            doc => 'The technology type that generated these variants (i.e polyscan, polyphred)',
        ],
        processing_params_id => [is => 'String',
                                 doc => 'The id of the row containing the processing params for this technology.',
        ],
    ],
};

sub sub_command_sort_position { 1000 }

sub help_brief {
    "adds data to or creates models for samplegenotype and its children"
}

sub help_synopsis {
    return <<"EOS"
genome-model add-sample-ge---- you know what, don't use this on the command line.
EOS
}

sub help_detail {
    return <<"EOS"
    "Adds data to or creates models for SampleGenotype and its children..."
EOS
}


sub execute {
    my $self = shift;

    my $input_data = $self->input_data;
    my $technology_type = $self->technology_type;
    my $processing_params_id = $self->processing_params_id;

    # The first level of the hash is by sample... iterate through each sample...
    for my $sample_name (keys $input_data) {
        my @sample_genotype_models = Genome::Model::SampleGenotype->get(sample_name => $sample_name);

        # There should only be one model per sample... if we have more than 1 we needs to sort it out
        if (@sample_genotype_models > 1){
            $self->error_message("Multiple SampleGenotype models for sample name $sample_name found");
            return undef;
        }
 
        my $sample_genotype_model = $sample_genotype_models[0];

        # Create the model if it doesnt already exist
        unless($sample_genotype_model) {
            # Get the processing profile or create it if it does not exist... should be generic...
            my @processing_profiles = Genome::ProcessingProfile->get(type_name => 'sample genotype');

            if (@processing_profiles > 1){
                $self->error_message("Multiple processing profiles for type name 'sample genotype' found");
                return undef;
            }

            my $processing_profile = $processing_profiles[0];

            unless($processing_profile) {
                $processing_profile = Genome::ProcessingProfile::SampleGenotype->create(name => 'sample_genotype');
            }

            #create sample genotype model
            $sample_genotype_model = Genome::Model::SampleGenotype->create(name => "$sample_name.sample_genotype",
                                                  sample_name => $sample_name
                                                  processing_profile => $processing_profile->id);
            
        }
        
        my $technology_model = $sample_genotype_model->get_model_for_type($technology_type);

        #create child model under sample model for this technology if it doesnt exist
        unless ($technology_model) {
            # Get the class path for the child and its processing profile
            my $child_class = "Genome::Model::" . ucfirst(lc($technology));
            my $child_profile_class = "Genome::ProcessingProfile::" . ucfirst(lc($technology));

            # Find the profile for this technology and params if it exists
            my @child_profiles = $child_profile_class->get(processing_params_id => $processing_params_id);
            if (@child_profiles > 1){
                $self->error_message("Multiple processing profiles for processing_params_id: $processing_params_id found");
                return undef;
            }

            # Create the profile for the child technology if it doesnt exist
            my $child_profile = @child_profiles[0];
            unless($child_profile) {
                $child_profile = $child_profile_class->create(name => "$technology.$processing_params_id",
                                                              processing_params_id => $processing_params_id);
                unless ($child_profile) {
                    $self->error_message("Create failed for new child technology processing profile using class: $child_profile_class");
                    return undef;
                }
            }
            
            my $child_model_name = "$sample_name.$technology.$processing_params_id";
            $technology_model = $child_class->create(name => $child_model_name,
                                                   sample_name => $sample_name,
                                                   processing_profile => $child_profile->id);
            unless ($technology_model) {
                $self->error_message("Failed to create child model class: $child_class with params: 
                    name = $child_model_name, sample_name = $sample_name, processing_profile = " . $child_profile->id);
                return undef;
            }

        }
        
        #parse data
        my $sample_data = $input_data->{$sample_name};
        my @data_to_add;
        foreach $position (keys $sample_data){ 
            push @data_to_add,  $sample_data->{$position};
        }

        # model for technology exists or has been created... archive and add data
        $technology_model->add_pcr_product_genotypes(@data_to_add);
    }
}

1;

