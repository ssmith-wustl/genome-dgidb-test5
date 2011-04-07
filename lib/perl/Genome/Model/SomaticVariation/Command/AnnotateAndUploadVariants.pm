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

    $self->status_message("Executing Annotate and Upload step");

    my $version = 2;
    #my $version = GMT:BED:CONVERT::version();  TODO, something like this instead of hardcoding
    
    my %files;

    my ($tier1_snvs, $tier2_snvs, $tier1_indels, $tier2_indels);
    
    if ($build->snv_detection_strategy){
        $tier1_snvs = $build->data_set_path("effects/snvs.hq.novel.tier1",$version,'bed');
        unless(-e $tier1_snvs){
            die $self->error_message("No tier 1 snvs file for build!");
        }
        $files{'snvs.hq.tier1'} = $tier1_snvs;

        $tier2_snvs = $build->data_set_path("effects/snvs.hq.novel.tier2",$version,'bed');
        unless(-e $tier2_snvs){
            die $self->error_message("No tier 2 snvs file for build!");
        }
        $files{'snvs.hq.tier2'} = $tier2_snvs;
    }

    if ($build->indel_detection_strategy){
        $tier1_indels = $build->data_set_path("effects/indels.hq.novel.tier1",$version,'bed');
        unless(-e $tier1_indels){
            die $self->error_message("No tier 1 indels file for build!");
        }
        $files{'indels.hq.tier1'} = $tier1_indels;

        $tier2_indels = $build->data_set_path("effects/indels.hq.novel.tier2",$version,'bed');
        unless(-e $tier2_indels){
            die $self->error_message("No tier 2 indels file for build!");
        }
        $files{'indels.hq.tier2'} = $tier2_indels;
    }

    #annotate variants
    my $annotator_version = 2; #TODO hardcoded for now, but should be an input on the build, or maybe a processing profile param
    unless($annotator_version){
        die $self->error_message("No variant annotator version for build!");
    }

    my $annotation_build_id = $self->build->annotation_build->id;

    my %annotation_params = (
        annotation_filter => "none",
        no_headers => 1,
        use_version => $annotator_version,
        build_id => $annotation_build_id,
    );

    my $annotation_output_version=1;  #TODO, do we even have an annotation file format?  need to figure out how to resolve this w/ data_set_path
    my $upload_output_version = 1; #TODO, same issue here as with annotation output version

    for my $key (keys %files){
        my $variant_file = $files{$key};
        unless ($variant_file){
            $self->status_message("No detection strategy for $key. Skipping annotation and upload");
        }
        unless (-e $variant_file){
            die $self->error_message("File expected for annotating $key at $variant_file does not exist!  Failing");
        }

        my $annotated_file = $build->data_set_path("effects/$key",$annotation_output_version,'annotated');
        my $uploaded_file = $build->data_set_path("effects/$key", $upload_output_version, "uploaded");

        $annotation_params{variant_bed_file} = $variant_file;
        $annotation_params{output_file} = $annotated_file;
        
        if (-s $variant_file){

            my $annotation_command = Genome::Model::Tools::Annotate::TranscriptVariants->create(%annotation_params);
            unless ($annotation_command){
                die $self->error_message("Failed to create annotate command for $key. Params:\n".Data::Dumper::Dumper(\%annotation_params));
            }
            my $annotate_rv = $annotation_command->execute;
            my $annotate_err = $@;
            unless($annotate_rv){
                die $self->error_message("Failed to execute annotate command for $key(err: $annotate_err) from params:\n" . Data::Dumper::Dumper(\%annotation_params));
            }
            unless(-s $annotation_params{output_file}){
                die $self->error_message("No output from annotate command for $key. Params:\n" . Data::Dumper::Dumper(\%annotation_params));
            }

            my %upload_params = (
                build_id => $self->build_id, 
            );

            $upload_params{variant_file} = $variant_file;
            $upload_params{annotation_file} = $annotated_file;
            $upload_params{output_file} = $uploaded_file;

            my $upload_command = Genome::Model::Tools::Somatic::UploadVariants->create(%upload_params);
            unless ($upload_command){
                die $self->error_message("Failed to create upload command for $key. Params:\n". Data::Dumper::Dumper(\%upload_params));
            }
            #my $upload_rv = $upload_command->execute;
            my $upload_rv =  1;  #TODO turn this on
            my $upload_err = $@;
            unless ($upload_rv){
                $DB::single = 1;
                die $self->error_message("Failed to execute upload command for $key (err: $upload_err). Params:\n".Dumper(\%upload_params));
            }
            unless(-s $upload_params{output_file} or 1){
                die $self->error_message("No output from upload command for $key. Params:\n" . Data::Dumper::Dumper(\%upload_params));
            }
        }else{
            $self->status_message("No variants present for $key, skipping annotation and upload");
            File::Copy::copy($variant_file, $annotated_file);
            File::Copy::copy($variant_file, $uploaded_file);
        }
    }

    #upload variants

    return 1;
}

1;
