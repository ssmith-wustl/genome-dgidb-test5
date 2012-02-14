package Genome::Model::MutationalSignificance::Command::CreateMafFile;

use strict;
use warnings;

use Genome;

class Genome::Model::MutationalSignificance::Command::CreateMafFile {
    is => ['Command::V2'],
    has_input => [
        somatic_variation_build => {
            is => 'Genome::Model::Build::SomaticVariation',
        },
        build => {
            is => 'Genome::Model::Build',
        },
    ],
    has_output => [
        maf_file => {},
    ],
};

sub execute {
    my $self = shift;

    my $rand = rand();

    my $snv_file = $self->build->data_directory."/".$self->somatic_variation_build->id.".uhc.anno";

    #For now, get only the ultra-high-confidence variants
    #TODO: Make a separate list of pindel-only indels
    #TODO: Get files for manual review
    #TODO: Check count of variants to review and set aside if too many
    my $uhc_cmd = Genome::Model::Tools::Somatic::UltraHighConfidence->create(
        normal_bam_file => $self->somatic_variation_build->normal_bam,
        tumor_bam_file => $self->somatic_variation_build->tumor_bam,
        variant_file => $self->somatic_variation_build->data_set_path("effects/snvs.hq.tier1",1,"annotated"),
        output_file => $snv_file,
        filtered_file => $self->build->data_directory."/".$self->somatic_variation_build->id.".not_uhc.anno",
        reference => $self->somatic_variation_build->reference_sequence_build->fasta_file,
    );

    my $uhc_result = $uhc_cmd->execute;

    #TODO: Add reviewed variants back in
    #TODO: Add in the dbSnp variants that appear in COSMIC
    
    my $create_maf_cmd = Genome::Model::Tools::Capture::CreateMafFile->create(
        snv_file => $snv_file,
        snv_annotation_file => $snv_file,
        genome_build => '37', #TODO FIX!!!
        tumor_sample => $self->somatic_variation_build->tumor_build->model->subject->extraction_label, #TODO verify
        normal_sample => $self->somatic_variation_build->normal_build->model->subject->extraction_label, #TODO verify
        output_file => $self->build->data_directory."/".$self->somatic_variation_build->id.".maf",
    );

    my $create_maf_result = $create_maf_cmd->execute;

    $self->maf_file($self->build->data_directory."/".$self->somatic_variation_build->id.".maf");
    my $status = "Created MAF file ".$self->maf_file;
    $self->status_message($status);
    return 1;
}

1;
