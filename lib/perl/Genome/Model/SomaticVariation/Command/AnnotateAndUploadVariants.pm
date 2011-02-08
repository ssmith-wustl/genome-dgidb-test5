package Genome::Model::SomaticVariation::Command::AnnotateAndUploadVariants;

use strict;
use warnings;
use Genome;

class Genome::Model::SomaticVariation::Command::AnnotateAndUploadVariants{
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

    my %files;

    my $tier1_snvs = $build->tier1_snvs;
    unless(-e $tier1_snvs){
        die $self->error_message("No tier 1 snvs file for build!");
    }
    $files{tier1_snvs} = $tier1_snvs;

    my $tier2_snvs = $build->tier2_snvs;
    unless(-e $tier2_snvs){
        die $self->error_message("No tier 2 snvs file for build!");
    }
    $files{tier2_snvs} = $tier2_snvs;

    my $tier1_indels = $build->tier1_indels;
    unless(-e $tier1_indels){
        die $self->error_message("No tier 1 indels file for build!");
    }
    $files{tier1_indels} = $tier1_indels;

    my $tier2_indels = $build->tier2_indels;
    unless(-e $tier2_indels){
        die $self->error_message("No tier 2 indels file for build!");
    }
    $files{tier2_indels} = $tier2_indels;

    #annotate variants
    my $annotator_version = $build->annotator_version;
    unless($annotator_version){
        die $self->error_message("No variant annotator version for build!");
    }

    my $annotation_build_id = $self->build->annotation_build->id;

    my %annotation_params = (
        annotation_filter => "none",
        no_headers => 1,
        use_verson => $annotator_version,
        build_id => $annotation_build_id,
    );

    for my $key (keys %files){
        my $variant_file = $files{$key};
        $annotation_params{variant_bed_file} = $variant_file,
        $annotation_params{output_file} = "$variant_file.post_annotation",
        my $annotation_command = Genome::Model::Tools::Annotate::TranscriptVariants->create(%annotation_params);
        unless ($annotation_command){
            die $self->error_message("Failed to create annotate command for $key. Params:\n".Data::Dumper::Dumper(\%annotation_params));
        }
        my $rv = $annotation_command->execute;
        my $err = $@;
        unless($rv){
            die $self->error_message("Failed to execute annotate command for $key(err: $err) from params:\n" . Data::Dumper::Dumper(\%annotation_params));
        }
        unless(-s $annotation_params{output_file}){
            die $self->error_message("No output from annotate command for $key. Params:\n" . Data::Dumper::Dumper(\%annotation_params));

        }
    }

    #upload variants

    my %upload_params = (
        build_id => $self->build_id, 
    );


    for my $key (keys %files){
        my $variant_file = $files{$key};
        $upload_params{variant_file} = $variant_file;
        $upload_params{annotation_file} = "$variant_file.post_annotation";
        $upload_params{output_file} = "$variant_file.post_upload";
        my $upload_command = Genome::Model::Tools::Somatic::UploadVariants(%upload_params);
        unless ($upload_command){
            die $self->error_message("Failed to create upload command for $key. Params:\n". Data::Dumper::Dumper(\%upload_params));
        }
        my $rv = $upload_command->execute;
        my $err = $@;
        unless ($rv){
            die $self->error_message("Failed to execute upload command for $key (err: $err). Params:\n".Dumper(\%upload_params));
        }
        unless(-s $upload_params{output_file}){
            die $self->error_message("No output from upload command for $key. Params:\n" . Data::Dumper::Dumper(\%upload_params));
        }
    }

    return 1;
}

1;
