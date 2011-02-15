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

    $DB::single=1;

    my $snv_feature_list = $prev_variations_build->snv_feature_list;

    my $indel_feature_list = $prev_variations_build->indel_feature_list;

    unless ($indel_feature_list or $snv_feature_list){
        die $self->error_message("No indel or snv feature list found on previously discovered variations build. This is unsupported!  Failing.");
    }

    my $version = 2;
    #my $version = GMT:BED:CONVERT::version();  TODO, something like this instead of hardcoding

    if ($build->snv_detection_strategy){
        my $detected_snv_path = $build->data_set_path("variants/snv_hq_output",$version,"bed"); 
        my $novel_detected_snv_path = $build->data_set_path("novel/snvs.hq",$version,'bed');

        if ($snv_feature_list){

            unless (-e $detected_snv_path){
                die $self->error_message("No high confidence detected snvs to filter against previously discovered variants");
            }

            if (-s $detected_snv_path){
                my $snv_output_tmp_file = Genome::Sys::Filesystem->create_temp_file();
                my $snv_compare = Genome::Model::Tools::CmpBed::Snv->create(
                    input_file_a => $detected_snv_path,
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
                $self->status_message("Intersection against previously discovered snv feature list complete");
                File::Copy::copy($snv_output_tmp_file, $novel_detected_snv_path);
            }else{
                $self->status_message("high confidence snv output is empty, skipping intersection");
                File::Copy::copy($detected_snv_path, $novel_detected_snv_path);
            }

        }else{
            $self->status_message("No snv feature list found on previously discovered variations build, skipping snv intersection");
            File::Copy::copy($detected_snv_path, $novel_detected_snv_path);
        }

    }

    if ($build->indel_detection_strategy){
        my $detected_indel_path =$build->data_set_path("variants/indel_hq_output",$version,"bed"); 
        my $novel_detected_indel_path = $build->data_set_path("novel/indels.hq",$version,"bed");

        if ($indel_feature_list){

            unless (-e $detected_indel_path){
                die $self->error_message("No high confidence detected indels to filter against previously discovered variants");
            }

            if (-s $detected_indel_path){
                my $indel_output_tmp_file = Genome::Sys::Filesystem->create_temp_file();
                my $indel_compare = Genome::Model::Tools::CmpBed::Indel->create(
                    input_file_a => $detected_indel_path,
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
                $self->status_message("Intersection against previously discovered indel feature list complete");
                File::Copy::copy($indel_output_tmp_file, $novel_detected_indel_path);
            }else{
                $self->status_message("high confidence indel output is empty, skipping intersection");
                File::Copy::copy($detected_indel_path, $novel_detected_indel_path);
            }

        }else{
            $self->status_message("No indel feature list found on previously discovered variations build, skipping indel intersection");
            File::Copy::copy($detected_indel_path, $novel_detected_indel_path);
        }
    }

    $self->status_message("Identify Previously Discovered Variations step completed");
    return 1;
}

1;

