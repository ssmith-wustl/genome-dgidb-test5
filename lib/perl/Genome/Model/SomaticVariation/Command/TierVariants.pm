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
        },
        _tier_file_location => {
            is => 'Text',
            is_optional => 1,
        },
    ],
};

sub execute {
    my $self = shift;
    my $build = $self->build;
    unless ($build){
        die $self->error_message("no build provided!");
    }

    $self->status_message("executing tier variants step on snvs and indels");

    #my $version = gmt:bed:convert::version();  todo, something like this instead of hardcoding
    my $version = 2;
    my $tiering_version = $build->tiering_version;
    $self->status_message("Using tiering_bed_files version ".$tiering_version);
    my $tier_file_location = $build->annotation_build->tiering_bed_files_by_version($tiering_version);

    unless (-d $tier_file_location){
        die $self->error_message("Couldn't find tiering bed files from annotation build");
    }

    $self->_tier_file_location($tier_file_location);

    if ($build->snv_detection_strategy){
        for my $name_set (["novel","snvs.hq.novel"], ["novel","snvs.hq.previously_detected"], ["variants","snvs.lq"]){ #want to tier lq, previously_discovered, and novel snvs 
            $self->run_fast_tier($name_set, $version, 'bed');
        }
    }else{
        $self->status_message("No snv detection strategy, skipping snv tiering");
    }

    if ($build->indel_detection_strategy){
        for my $name_set (["novel","indels.hq.novel"], ["novel","indels.hq.previously_detected"], ["variants","indels.lq"]){ #want to tier lq, previously_discovered, and novel indels 
            $self->run_fast_tier($name_set, $version, 'bed');
        }

    }else{
        $self->status_message("No indel detection strategy, skipping indel tiering");
    }

    $self->status_message("Tier Variants step completed");

    return 1;
}


sub run_fast_tier {
    my $self = shift;
    my ($name_set, $version, $format) =  @_;

    #breaking up filename and subdir parts of the data set path so we can put the output tiering files in the effects directory
    my $dir = $$name_set[0];
    my $name = $$name_set[1];

    my $build = $self->build;

    my $path_to_tier = $build->data_set_path("$dir/$name",$version,$format);
    unless (-e $path_to_tier){
        die $self->error_message("No $name file for build!");
    }

    my ($tier1_path, $tier2_path, $tier3_path, $tier4_path) = map {$build->data_set_path("effects/$name.tier".$_,$version,$format)}(1..4);

    my %params;
    if (-s $path_to_tier){
        %params = (
            variant_bed_file => $path_to_tier,
            tier_file_location => $self->_tier_file_location,
            tier1_output => $tier1_path,
            tier2_output => $tier2_path,
            tier3_output => $tier3_path,
            tier4_output => $tier4_path,
        );
        my $tier_snvs_command = Genome::Model::Tools::FastTier::FastTier->create(%params);
        unless ($tier_snvs_command){
            die $self->error_message("Couldn't create fast tier command from params:\n" . Data::Dumper::Dumper(\%params));
        }
        my $snv_rv = $tier_snvs_command->execute;
        my $snv_err =$@;
        unless($snv_rv){
            die $self->error_message("Failed to execute fast tier command(err: $snv_err) with params:\n" . Data::Dumper::Dumper(\%params));
        }
    }else{
        $self->status_message("No detected variants for $name, skipping tiering");
        map {File::Copy::copy($path_to_tier, $_)}($tier1_path, $tier2_path, $tier3_path, $tier4_path);
    }
    unless(-e "$tier1_path" and -e "$tier2_path" and -e "$tier3_path" and -e "$tier4_path"){
        die $self->error_message("SNV fast tier output not found with params:\n" . (%params?(Data::Dumper::Dumper(\%params)):''));
    }
}

1;

