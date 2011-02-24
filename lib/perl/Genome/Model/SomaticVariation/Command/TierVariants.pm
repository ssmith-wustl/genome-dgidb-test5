package Genome::Model::SomaticVariation::Command::TierVariants;

use strict;
use warnings;
use Genome;

class Genome::Model::SomaticVariation::Command::TierVariants{
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

    $self->status_message("Executing Tier Variants step on snvs and indels");

    my $version = 2;
    #my $version = GMT:BED:CONVERT::version();  TODO, something like this instead of hardcoding
    
    my $tier_file_location = $build->annotation_build->tier_file_directory;

    unless (-d $tier_file_location){
        die $self->error_message("Couldn't find tiering bed files from annotation build");
    }

    if ($build->snv_detection_strategy){

        my $novel_detected_snvs_path = $build->data_set_path("novel/snvs.hq",$version,'bed');
        unless (-e $novel_detected_snvs_path){
            die $self->error_message("No novel_detected_snvs file for build!");
        }

        my ($tier1_path, $tier2_path, $tier3_path, $tier4_path) = map {$build->data_set_path("effects/snvs.hq.tier".$_,$version,'bed')}(1..4);

        if (-s $novel_detected_snvs_path){
            my %snvs_params = (
                variant_bed_file => $novel_detected_snvs_path,
                tier_file_location => $tier_file_location,
                tier1_output => $tier1_path,
                tier2_output => $tier2_path,
                tier3_output => $tier3_path,
                tier4_output => $tier4_path,
            );
            my $tier_snvs_command = Genome::Model::Tools::FastTier::FastTier->create(%snvs_params);
            unless ($tier_snvs_command){
                die $self->error_message("Couldn't create fast tier command from params:\n" . Data::Dumper::Dumper(\%snvs_params));
            }
            my $snv_rv = $tier_snvs_command->execute;
            my $snv_err =$@;
            unless($snv_rv){
                die $self->error_message("Failed to execute fast tier command(err: $snv_err) with params:\n" . Data::Dumper::Dumper(\%snvs_params));
            }

            unless(-s "$tier1_path" and -s "$tier2_path" and -s "$tier3_path" and -s "$tier4_path"){
                die $self->error_message("SNV fast tier output not found with params:\n" . Data::Dumper::Dumper(\%snvs_params));
            }
        }else{
            $self->status_message("No novel detected snvs, skipping snv tiering");
            map {File::Copy::copy($novel_detected_snvs_path, $_)}($tier1_path, $tier2_path, $tier3_path, $tier4_path);
        }

    }else{
        $self->status_message("No snv detection strategy, skipping snv tiering");
    }

    if ($build->indel_detection_strategy){

        my $novel_detected_indels_path = $build->data_set_path("novel/indels.hq",$version,'bed');
        unless (-e $novel_detected_indels_path){
            die $self->error_message("No novel_detected_indels file for build!");
        }
        
        my ($tier1_path, $tier2_path, $tier3_path, $tier4_path) = map {$build->data_set_path("effects/indels.hq.tier".$_,$version,'bed')}(1..4);

        if (-s $novel_detected_indels_path){
            my %indels_params = (
                variant_bed_file => $novel_detected_indels_path,
                indels => 1,
                tier_file_location => $tier_file_location,
                tier1_output => $tier1_path,
                tier2_output => $tier2_path,
                tier3_output => $tier3_path,
                tier4_output => $tier4_path,
            );

            my $tier_indels_command = Genome::Model::Tools::FastTier::FastTier->create(%indels_params);
            unless ($tier_indels_command){
                die $self->error_message("Couldn't create fast tier command from params:\n" . Data::Dumper::Dumper(\%indels_params));
            }
            my $indel_rv = $tier_indels_command->execute;
            my $indel_err =$@;
            unless($indel_rv){
                die $self->error_message("Failed to execute fast tier command(err: $indel_err) with params:\n" . Data::Dumper::Dumper(\%indels_params));
            }

            unless(-s "$tier1_path" and -s "$tier2_path" and -s "$tier3_path" and -s "$tier4_path"){
                die $self->error_message("Indel fast tier output not found with params:\n" . Data::Dumper::Dumper(\%indels_params));
            }
        }else{
            $self->status_message("No novel detected indels, skipping indel tiering");
            map {File::Copy::copy($novel_detected_indels_path, $_)}($tier1_path, $tier2_path, $tier3_path, $tier4_path);
        }

    }else{
        $self->status_message("No indel detection strategy, skipping indel tiering");
    }

    $self->status_message("Tier Variants step completed");

    return 1;
}

1;

