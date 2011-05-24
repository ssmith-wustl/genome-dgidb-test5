package Genome::Model::Build::SomaticVariation;

use strict;
use warnings;

use Genome;
use File::Basename;

class Genome::Model::Build::SomaticVariation {
    is => 'Genome::Model::Build',
    has => [
        tumor_model => {
            is => 'Genome::Model::ReferenceAlignment',
            via => 'model',
        },
        tumor_build_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'tumor_build', value_class_name => 'Genome::Model::Build::ReferenceAlignment' ],
            is_mutable => 1,
        },
        tumor_build => {
            is => 'Genome::Model::Build::ReferenceAlignment',
            id_by => 'tumor_build_id',
        },
        normal_model => {
            is => 'Genome::Model::ReferenceAlignment',
            via => 'model',
        },
        normal_build => {
            is => 'Genome::Model::Build::ReferenceAlignment',
            via => 'inputs',
            is_many => 0,
            to => 'value',
            where => [ name => 'normal_build', value_class_name => 'Genome::Model::Build::ReferenceAlignment' ],
            is_mutable => 1,
        },
#        normal_build_id => {
#            is => 'Text',
#            via => 'inputs',
#            to => 'value_id',
#            where => [ name => 'normal_build', value_class_name => 'Genome::Model::Build::ReferenceAlignment' ],
#            is_mutable => 1,
#        },
        #normal_build => {
        #    is => 'Genome::Model::Build::ReferenceAlignment',
        #    id_by => 'normal_build_id',
        #},
        annotation_build => {
            is => 'Genome::Model::Build::ImportedAnnotation',
            via => 'model',
        },
        previously_discovered_variations_build => {
            is => 'Genome::Model::Build::ImportedVariationList',
            via => 'model',
        },
        snv_detection_strategy => {
            is => 'Text',
            via => 'model',
        },
        sv_detection_strategy => {
            is => 'Text',
            via => 'model',
        },
        indel_detection_strategy => {
            is => 'Text',
            via => 'model',
        },
        cnv_detection_strategy => {
            is => 'Text',
            via => 'model',
        },
        tiering_version => {
            is => 'Text',
            via => 'model',
        },
        loh_version => {
            is => 'Text',
            via => 'model',
        },
   ],
};


sub create {
    my $class = shift;

    #This updates the model's tumor and normal build inputs so they are the latest complete build for copying to build inputs
    my $bx = $class->define_boolexpr(@_);
    $DB::single = 1; #TODO:delete me
    my $model_id = $bx->value_for('model_id');
    my $model = Genome::Model->get($model_id);
    $model->update_tumor_and_normal_build_inputs;

    my $self = $class->SUPER::create(@_);

    unless ($self) {
        return;
    }
    
    $model = $self->model;
    unless ($model) {
        $self->error_message("Failed to get a model for this build!");
        return;
    }

    my $tumor_model = $model->tumor_model;
    unless ($tumor_model) {
        $self->error_message("Failed to get a tumor_model!");
        return;
    }
    
    my $normal_model = $model->normal_model;
    unless ($normal_model) {
        $self->error_message("Failed to get a normal_model!");
        return;
    }
    
    my $tumor_build = $self->tumor_build;
    unless ($tumor_build) {
        $self->error_message("Failed to get a tumor build!");
        return;
    }

    my $normal_build = $self->normal_build;
    unless ($normal_build) {
        $self->error_message("Failed to get a normal build!");
        return;
    }

    my @result_subfolders;
    for ('variants', 'novel', 'effects'){
        push @result_subfolders, $self->data_directory."/$_";
    }

    for (@result_subfolders){
        mkdir $_ unless -d $_;
    }

    return $self;
}

sub tumor_bam {
    my $self = shift;
    $DB::single = 1;
    my $tumor_build = $self->tumor_build;
    my $tumor_bam = $tumor_build->whole_rmdup_bam_file;
    unless ($tumor_bam){
        die $self->error_message("No whole_rmdup_bam file found for tumor build!");
    }
    return $tumor_bam;
}

sub normal_bam {
    my $self = shift;
    my $normal_build = $self->normal_build;
    my $normal_bam = $normal_build->whole_rmdup_bam_file;
    unless ($normal_bam){
        die $self->error_message("No whole_rmdup_bam file found for normal build!");
    }
    return $normal_bam;
}

sub reference_sequence_build {
    my $self = shift;
    my $normal_build = $self->normal_build;
    my $normal_model = $normal_build->model;
    my $reference_sequence_build = $normal_model->reference_sequence_build;
    return $reference_sequence_build;
}

sub data_set_path {
    my ($self, $dataset, $version, $file_format) = @_;
    my $path;
    $version =~ s/^v//;
    if ($version and $file_format){
        $path = $self->data_directory."/$dataset.v$version.$file_format";
    }
    return $path;
}

sub calculate_estimated_kb_usage {
    my $self = shift;

    # 30 gig -- a majority of builds (using the April processing profile) end up being 15-20gig with the usual max being 25+=. Extreme maximums of 45g are noted but rare.
    return 31457280;
}

sub files_ignored_by_diff {
    return qw(
        reports/Build_Initialized/report.xml
        reports/Build_Succeeded/report.xml
        variants/dispatcher.cmd
        \.vcf$
        \.vcf.idx$
        workflow\.xml$
        \.png$
        readcounts$
        variants/sv/breakdancer
    );
}

sub dirs_ignored_by_diff {
    return qw(
        logs/
        /\d+/
        variants/sv/breakdancer
    );
}

sub workflow_instances {
    my $self = shift;
    my @instances = Workflow::Operation::Instance->get(
        name => $self->workflow_name
    );

    #older builds used a wrapper workflow
    unless(scalar @instances) {
        return $self->SUPER::workflow_instances;
    }

    return @instances;
}

sub workflow_name {
    my $self = shift;
    return $self->build_id . ' Somatic Variation Pipeline';
}

1;
