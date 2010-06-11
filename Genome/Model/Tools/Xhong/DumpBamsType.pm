package Genome::Model::Tools::Xhong::DumpBamsType;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;

class Genome::Model::Tools::Xhong::DumpBamsType {
    is => 'Command',
    has => [
    build_ids => { 
        type => 'String',
        is_optional => 1,
        doc => "build ids of the build to process. comma separated",
    },
    model_ids =>{
    	type => 'String',
    	is_optional => 1,
    	doc => "build ids of the model to process, comma separated",
    },
    model_group_name => {
        type => 'String',
        is_optional => 1,
        doc => 'model-group containing only somatic models. Current running builds will be used if no successful build is available',
    },
    ]
};


sub execute {
    my $self=shift;
    $DB::single = 1;
    my @builds;
    
    if($self->build_ids) {
        @builds = map { Genome::Model::Build->get($_) } split /,/, $self->build_ids;
    }
    elsif($self->model_ids){
    	my@models = map { Genome::Model->get($_) } split /,/, $self->model_ids;
    @builds=grep{defined $_} map {$_->last_succeeded_build ? $_->last_succeeded_build : $_->current_running_build ? $_->current_running_build : undef} @models;
    }
    elsif($self->model_group_name) {
        my $group = Genome::ModelGroup->get(name => $self->model_group_name);
        @builds = grep { defined $_ } map {$_->last_succeeded_build ? $_->last_succeeded_build : $_->current_running_build ? $_->current_running_build : undef } $group->models;
    }

    foreach my $build (@builds) {
        
        my $model = $build->model;
        unless(defined($model)) {
            $self->error_message("Somehow this build does not have a model");
            return;
        }
#        unless($model->type_name eq 'somatic') {
#            $self->error_message("This build must be a somatic pipeline build");
#            return;
#        }

	my $datadir=$build->data_directory;
	my $system_path=$model->_build_model_filesystem_paths();
	my $subject=$model->subject_type;
	printf "%s\n%s\n%s\n%s\n%s\n%s\n%s\n", $model->id, $model->subject_name, $model->subject_type, $model->type_name, $datadir, $build->status, $build->processing_profile_name;
#        my $tumor_build = $build->tumor_build;
#        my $normal_build = $build->normal_build;

#        my $tumor_common_name = $tumor_build->model->subject->source_common_name;
#        my $tumor_type = $tumor_build->model->subject->common_name;
#        my $tumor_datadir= $tumor_build->data_directory;
#        my $normal_common_name = $normal_build->model->subject->source_common_name;
#        my $normal_type = $normal_build->model->subject->common_name;
#	my $normal_datadir= $normal_build->data_directory;
#        next unless($tumor_build->model->subject->sub_type !~ /M[13]/);

#        printf "%s\n%s\n%s\n%s %s: %s\n%s %s: %s\n",$model->type_name, $tumor_build->data_directory, $normal_build->data_directory, $tumor_common_name, $tumor_type, $tumor_build->whole_rmdup_bam_file, $normal_common_name, $normal_type, $normal_build->whole_rmdup_bam_file;

    }
    return 1;

}


1;

sub help_brief {
    "Give the bam files of somatic builds"
}

sub help_detail {
    <<'HELP';
This dumps the filtered.snps file locations for the tumor and normal builds used in somatic models
HELP
}
