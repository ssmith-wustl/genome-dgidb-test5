package Genome::Model::Build::MetagenomicCompositionShotgun;

use strict;
use warnings;
use Genome;

class Genome::Model::Build::MetagenomicCompositionShotgun{
    is => 'Genome::Model::Build',
    has =>[
        _final_metagenomic_bam => {
            is_calculated => 1,
            calculate_from => ['data_directory'],
            calculate => sub {
                my ($data_directory) = @_;
                $data_directory."/metagenomic_alignment.combined.sorted.bam";
            },
        },
        _contamination_screen_alignment_build => {
            is => 'Genome::Model::Build::ReferenceAlignment',
            via => 'from_build_links',
            to => 'from_build',
            where => [role => 'contamination_screen_alignment_build'],
        },
        contamination_screen_reference=>{
            is => 'Genome::Model::Build::ReferenceAlignment',
            via => 'model',
        },
        _metagenomic_alignment_builds => {
            is => 'Genome::Model::Build::ReferenceAlignment',
            is_many => 1,
            via => 'from_build_links',
            to => 'from_build',
            where => [role => 'metagenomic_alignment_build'],
        },
        metagenomic_references =>{
            is =>'Genome::Model::Build::ReferenceAlignment',
            via => 'model',
        },
        _unaligned_metagenomic_alignment_build => {
            is => 'Genome::Model::Build::ReferenceAlignment',
            is_many=> 1,
            via => 'from_build_links',
            to => 'from_build',
            where => [role => 'unaligned_metagenomic_alignment_build'],
        },
        unaligned_metagenomic_alignment_reference => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            via => 'model',
        },
        _first_viral_verification_alignment_build => {
            is => 'Genome::Model::Build::ReferenceAlignment',
            is_many=> 1,
            via => 'from_build_links',
            to => 'from_build',
            where => [role => 'first_viral_verification_alignment_build'],
        },
        first_viral_verification_alignment_reference => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            via => 'model',
        },
        _second_viral_verification_alignment_build => {
            is => 'Genome::Model::Build::ReferenceAlignment',
            is_many=> 1,
            via => 'from_build_links',
            to => 'from_build',
            where => [role => 'second_viral_verification_alignment_build'],
        },
        second_viral_verification_alignment_reference => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            via => 'model',
        },
    ],
};

sub calculate_estimated_kb_usage {
    return 50_000_000;
}

sub sra_sample_id {
    my $self = shift;
    my @id = $self->instrument_data;
    die "no instrument data unless id" unless @id;
    my $sra_sample_id = $id[0]->sra_sample_id;
    die "no sra_sample_id specified for instrument data" unless $sra_sample_id;
    return $sra_sample_id;
}

sub files_ignored_by_diff {
    return qw(
        reports/Build_Initialized/report.xml
        reports/Build_Succeeded/report.xml
        build.xml
    );
}

sub dirs_ignored_by_diff {
    return qw(
        logs/
    );
}
1;

