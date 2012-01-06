package Genome::Model::SomaticVariation::Command::ExtractValidationCandidates;

use strict;
use warnings;
use Genome;
use Genome::Info::IUB;

class Genome::Model::SomaticVariation::Command::ExtractValidationCandidates {
    is => 'Command::V2',
    has =>[
       output_directory => {
            is => 'String',
            is_input => 1,
            is_output => 1,
            doc => 'Place validtion candidates output here',
        },
    ],
    has_optional => [
        build => {
            is => 'Genome::Model::Build::SomaticVariation',
            doc => 'somatic-variation build object to run command on. Specify this OR build_id, but NOT BOTH!',
        },
        build_id => {
            is => 'Text',
            doc => 'somatic-variation build ID to run commmand on. Specy this OR build, but NOT BOTH!',
        },
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
    unless(defined($self->build) xor defined($self->build_id)){
        die $self->error_message("Please define build OR build_id, but not both.");
    }
    my $build = defined($self->build)? $self->build: Genome::Model::Build->get($self->build_id);
    unless(defined($build)){
        die $self->error_message("Could not get a build object to operate on, either from build or build_id param!");
    }
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
    my @possible_ssmq_directories = glob( $variants_dir."/snv/sniper*/false-positive-*/somatic-score-mapping-quality-*");
    unless(@possible_ssmq_directories == 1){
        die $self->status_message("Found ".scalar(@possible_ssmq_directories)." results when looking for somatic-score-mapping-quality directory!");
    }

    my $ssmq_dir=$possible_ssmq_directories[0];
    unless(-d $ssmq_dir){
        die $self->error_message("Could not locate somatic-score-mapping-quality filter directory at: ".$ssmq_dir);
    }

    my @filtered_samtools = glob($variants_dir."/snv/samtools-*/snp-filter-*/snvs.hq.bed");
    unless(@filtered_samtools == 1){
        die $self->error_message("Found ".scalar(@filtered_samtools)." results when searching for snp-filter'ed samtools results");
    }
    my $filtered_samtools = $filtered_samtools[0];
    unless(-e $filtered_samtools){
        die $self->error_message("Could not locate samtools filtered output at: ".$filtered_samtools);
    }

    Genome::Sys->copy_file($ssmq_dir."/snvs.lq.bed",$lq_tiers."/snvs.lq.bed");

    $self->status_message("Now running fast-tier on somatic-score-mapping-quality lq output.");

    my $tier_cmd = Genome::Model::Tools::FastTier::FastTier->create(
                    variant_bed_file => $lq_tiers."/snvs.lq.bed",
                    tier_file_location => $tier_file_location,
                    tiering_version => $tiering_version,
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
    my $snv_result = $pdv->snv_result;

    my $dbsnp_file = defined($self->dbsnp_bed_file) ? $self->dbsnp_bed_file: $snv_result->output_dir."/snvs.hq.bed";
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
