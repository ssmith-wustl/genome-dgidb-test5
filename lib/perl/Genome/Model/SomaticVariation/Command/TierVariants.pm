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

    my $snvs = $build->novel_detected_snvs;
    unless (-e $snvs){
        die $self->error_message("No novel_detected_snvs file for build!");
    }
    
    my $indels = $build->novel_detected_indels;
    unless (-e $indels){
        die $self->error_message("No novel_detected_indels file for build!");
    }
    
    my $tier_file_directory = $build->annotation_build->tier_file_directory;
    unless(-d $tier_file_directory){
        die $self->error_message("No tier file directory for annotation build!");
    }

    my %snvs_params = (
        variant_bed_file => $snvs,
        tier_file_directory => $tier_file_directory,
    );

    my %indels_params = (
        variant_bed_file => $indels,
        indels => 1,
        tier_file_directory => $tier_file_directory
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

    unless(-s "$snvs.tier1" and -s "$snvs.tier2" and -s "$snvs.tier3" and -s "$snvs.tier4"){
        die $self->error_message("SNV fast tier output not found with params:\n" . Data::Dumper::Dumper(\%snvs_params));
    }

    my $tier_indels_command = Genome::Model::Tools::FastTier::FastTier->create(%indels_params);
    unless ($tier_indels_command){
        die $self->error_message("Couldn't create fast tier command from params:\n" . Data::Dumper::Dumper(\%indels_params));
    }
    my $indel_rv = $tier_indels_command->execute;
    my $indel_err =$@;
    unless($indel_rv){
        die $self->error_message("Failed to execute fast tier command(err: $indel_err) with params:\n" . Data::Dumper::Dumper(\%indels_params));
    }

    unless(-s "$indels.tier1" and -s "$indels.tier2" and -s "$indels.tier3" and -s "$indels.tier4"){
        die $self->error_message("SNV fast tier output not found with params:\n" . Data::Dumper::Dumper(\%indels_params));
    }

    return 1;
}

1;

