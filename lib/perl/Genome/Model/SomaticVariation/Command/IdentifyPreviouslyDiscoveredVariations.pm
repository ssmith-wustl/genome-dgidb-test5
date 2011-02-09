package Genome::Model::SomaticVariation::Command::IdentifyPreviouslyDiscoveredVariations;

use strict;
use warnings;
use Genome;

class Genome::Model::SomaticVariation::Command::IdentifyPreviouslyDiscoveredVariations{
    is => 'Genome::Command::Base',
    has =>[
        build_id => {
            is => 'Integer',
            is_input => 1,
            is_output => 1,
            doc => 'build id of SomaticVariation model',
        },
        build => {
            is => 'Genome::Model::Build::SomaticVariation',
            id_by => 'build_id',
        }
    ],
};

sub execute{
    my $self = shift;
    my $build = $self->build;
    unless ($build){
        die $self->error_message("no build provided!");
    }

    $self->status_message("Comparing detected variants to previously discovered variations");

    my $prev_variations_build = $build->previously_discovered_variations_build;
    unless ($prev_variations_build){
        die $self->error_message("No previous variations build found on somatic build!");
    }

    my $snv_feature_list = $prev_variations_build->snv_feature_list;
    unless ($snv_feature_list){
        die $self->error_message("No snv feature list found on previously discovered variations build");
    }
    
    my $indel_feature_list = $prev_variations_build->indel_feature_list;
    unless ($indel_feature_list){
        die $self->error_message("No indel feature list found on previously discovered variations build");
    }

    my $detected_snvs = $build->high_confidence_snvs; #TODO, final accessor name?
    unless (-e $detected_snvs){
        die $self->error_message("No high confidence detected snvs to filter against previously discovered variants");
    }
    
    my $detected_indels = $build->high_confidence_indels; #TODO, final accessor name?
    unless (-e $detected_indels){
        die $self->error_message("No high confidence detected indels to filter against previously discovered variants");
    }

    my $snv_output_tmp_file = Genome::Sys::Filesystem->create_temp_file();
    my $snv_compare = Genome::Model::Tools::CmpBed::Snv->create(
        input_file_a => $detected_snvs,
        input_file_b => $snv_feature_list,
        output_file => $snv_output_tmp_file,
    );
    unless ($snv_compare){
        die $self->error_message("Couldn't create snv comparison tool!");
    }
    my $snv_rv = $snv_compare->execute();
    my $snv_err = $@;
    unless ($snv_rv){
        die $self->error_message("Failed to execute snv comparison(err: $snv_err )");
    }
    my $novel_detected_snv_path = $build->novel_detected_snvs;
    File::Copy::move($snv_output_tmp_file, $novel_detected_snv_path);

    my $indel_output_tmp_file = Genome::Sys::Filesystem->create_temp_file();
    my $indel_compare = Genome::Model::Tools::CmpBed::Indel->create(
        input_file_a => $detected_indels,
        input_file_b => $indel_feature_list,
        output_file => $indel_output_tmp_file,
    );
    unless ($indel_compare){
        die $self->error_message("Couldn't create indel comparison tool!");
    }
    my $indel_rv = $indel_compare->execute();
    my $indel_err = $@;
    unless ($indel_rv){
        die $self->error_message("Failed to execute indel comparison(err: $indel_err )");
    }
    my $novel_detected_indel_path = $build->novel_detected_indels;
    File::Copy::move($indel_output_tmp_file, $novel_detected_indel_path);

    return 1;
}

1;

