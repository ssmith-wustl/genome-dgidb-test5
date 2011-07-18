package Genome::Model::SomaticVariation::Command::ExtractValidationCandidates;

use strict;
use warnings;
use Genome;
use Genome::Info::IUB;

class Genome::Model::SomaticVariation::Command::ExtractValidationCandidates {
    is => 'Command::V2',
    has =>[
        build => {
            is => 'Genome::Model::Build::SomaticVariation',
        },
        output_directory => {
            is => 'String',
            is_input => 1,
            is_output => 1,
            doc => 'Place validtion candidates output here',
        },
    ],
    has_optional => [
        dbsnp_bed_file => {
            is => 'String',
            is_input => 1,
            is_output => 1,
            doc => 'This bed will be intersected with LOH results',
        },
    ],
    has_param => [
        lsf_queue => {
            default => 'apipe',
        },
    ],
};


sub execute {
    my $self = shift;

    my $build = $self->build;

    my $reference_build_id = $build->reference_sequence_build->id;
    my $output_directory = $self->output_directory;
    my $anno_build = $build->annotation_build;
    my $tiering_version = $build->tiering_version;
    my $tier_file_location = $anno_build->tiering_bed_files_by_version($tiering_version);

    $self->status_message("Using tiering files from: ".$tier_file_location);

    unless(-d $output_directory){
        Genome::Sys->create_directory($output_directory);
    }
    my $lq_tiers = $output_directory."/lq_tiers";
    Genome::Sys->create_directory($lq_tiers);
    
    my $variants_dir = $build->data_directory."/variants";

    my @possible_ssmq_directories = qw(
        /snv/sniper-0.7.2--q_1_-Q_15/false-positive-v1-/somatic-score-mapping-quality-v1---min-mapping-score_40_--min-somatic-quality_40
        /snv/sniper-0.7.3--q_1_-Q_15/false-positive-v1-/somatic-score-mapping-quality-v1---min-mapping-score_40_--min-somatic-quality_40
        /snv/sniper-0.7.2--q_1_-Q_15/false-positive-v1-/somatic-score-mapping-quality-v1---min-mapping-quality_40_--min-somatic-score_40
        /snv/sniper-0.7.3--q_1_-Q_15/false-positive-v1-/somatic-score-mapping-quality-v1---min-mapping-quality_40_--min-somatic-score_40
    );

    my $ssmq_dir;
    for my $possible_subdirectory (@possible_ssmq_directories) {
        my $possible_path = $variants_dir.$possible_subdirectory;
        if (-d $possible_path) {
            $ssmq_dir = $possible_path;
            $self->status_message("Found somatic-score-mapping-quality directory at $ssmq_dir");
            last;
        }
    }
    unless($ssmq_dir){
        die $self->error_message("Could not locate somatic-score-mapping-quality filter directory!");
    }

    my $filtered_samtools = $variants_dir."/snv/samtools-r599-/snp-filter-v1-/snvs.hq.bed";
    unless(-e $filtered_samtools){
        die $self->error_message("Could not locate samtools filtered output at: ".$filtered_samtools);
    }
    Genome::Sys->copy_file($ssmq_dir."/snvs.lq.bed",$lq_tiers."/snvs.lq.bed");

    $self->status_message("Now running fast-tier on somatic-score-mapping-quality lq output.");

    my $tier_cmd = Genome::Model::Tools::FastTier::FastTier->create(
                    variant_bed_file => $lq_tiers."/snvs.lq.bed",
                    tier_file_location => $tier_file_location,
    );
    unless($tier_cmd->execute){
        die $self->error_message("Failed to run fast-tier on snvs.lq.bed!");
    }
    my $intersect_dir = $output_directory."/intersect_samtools";
    Genome::Sys->create_directory($intersect_dir);
    
    $self->status_message("Now intersecting tier1 lq results with filtered samtools results.");

    my $intersect_cmd = Genome::Model::Tools::Joinx::Intersect->create(
        input_file_a => $lq_tiers."/snvs.lq.bed.tier1",
        input_file_b => $filtered_samtools,
        output_file => $intersect_dir."/snvs.hq.bed",
        miss_a_file => $intersect_dir."/snvs.lq.a.bed",
    );
    unless($intersect_cmd->execute){
        die $self->error_message("Failed to run joinx-intersect with samtools output!");
    }
    my $loh_output = $output_directory."/loh";

    $self->status_message("Now checking for loh from intersected results.");

    my $loh_cmd = Genome::Model::SomaticVariation::Command::Loh->create( 
                    build => $build, 
                    output_directory => $loh_output,
                    variant_bed_file => $intersect_dir."/snvs.hq.bed",
    );
    unless($loh_cmd->execute){
        die $self->error_message("Failed to run loh.");
    } 

    my $dbsnp_dir = $output_directory."/dbsnp_intersection";
    Genome::Sys->create_directory($dbsnp_dir);

    my $pdv = $build->previously_discovered_variations_build;
    my $snv_feature_list = $pdv->snv_feature_list;

    my $dbsnp_file = defined($self->dbsnp_bed_file) ? $self->dbsnp_bed_file: $snv_feature_list->file_path ;
    unless(-e $dbsnp_file){
        die $self->error_message("DbSNP bed file does not exist at: ".$dbsnp_file);
    }

    $self->status_message("Now performing dbsnp intersection with file: ".$dbsnp_file);

    my $dbsnp_intersect_cmd = Genome::Model::Tools::Joinx::Intersect->create(
        input_file_a => $loh_output."/snvs.somatic.v2.bed",
        input_file_b => $dbsnp_file,
        output_file => $dbsnp_dir."/snvs.hq.bed",
        miss_a_file => $dbsnp_dir."/snvs.lq.a.bed",
        iub_match => 1,
    );
    unless($dbsnp_intersect_cmd->execute){
        die $self->error_message("Failed to intersect variants with dbsnp!");
    }

    my $validation_candidates = $output_directory."/validation_candidates";
    Genome::Sys->create_directory($validation_candidates);
    my $novel_tier1 = $build->data_directory."/effects/snvs.hq.novel.tier1.v2.bed";
    my $novel_tier2 = $build->data_directory."/effects/snvs.hq.novel.tier2.v2.bed";
    my $novel_tier3 = $build->data_directory."/effects/snvs.hq.novel.tier3.v2.bed";
    my $novel_tier1_result = $validation_candidates."/snvs.hq.novel.tier1.v2.bed";
    my $novel_tier2_result = $validation_candidates."/snvs.hq.novel.tier2.v2.bed";
    my $novel_tier3_result = $validation_candidates."/snvs.hq.novel.tier3.v2.bed";

    $self->status_message("Copying results into ".$validation_candidates);
   
    Genome::Sys->copy_file($novel_tier1,$novel_tier1_result);
    Genome::Sys->copy_file($novel_tier2,$novel_tier2_result);
    Genome::Sys->copy_file($novel_tier3,$novel_tier3_result);
    Genome::Sys->copy_file($dbsnp_dir."/snvs.hq.bed",$validation_candidates."/snvs.tier1_ssmq.hq.bed");

    $self->status_message("Validation Candidates have been deposited at: ".$validation_candidates);
    
    return 1;
}

1;    
