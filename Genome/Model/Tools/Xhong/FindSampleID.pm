package Genome::Model::Tools::Xhong::FindSampleID;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
# use Genome::Sample;

class Genome::Model::Tools::Xhong::FindSampleID {
    is => 'Command',
    has => [
    build_ids => { 
        type => 'String',
        is_optional => 1,
        doc => "build ids of the build to process. comma separated",
    },
    model_group_name => {
        type => 'String',
        is_optional => 1,
        doc => "model-group containing only somatic models. Current running builds will be used if no successful build is available",
    },
    common_name => {
	type => 'String',
	is_optional => 1,
	doc => "The sample name such as SJTALL012"	
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
	
#    Need to check if type_name is microarray-genotype
#        unless($model->type_name eq 'somatic') {
#            $self->error_message("This build must be a somatic pipeline build");
#            return;
#        }

        my $tumor_build = $build->tumor_build;
        my $normal_build = $build->normal_build;

        my $tumor_common_name = $tumor_build->model->subject->source_common_name;
        my $tumor_type = $tumor_build->model->subject->common_name;
#        my $tumor_datadir= $tumor_build->data_directory;
        my $normal_common_name = $normal_build->model->subject->source_common_name;
        my $normal_type = $normal_build->model->subject->common_name;
#	my $normal_datadir= $normal_build->data_directory;

        next unless($tumor_build->model->subject->sub_type !~ /M[13]/);

printf " %s\n", $model->type_name; 
        printf "%s %s: %s\n%s %s: %s\n",$tumor_common_name, $tumor_type, $tumor_build->whole_rmdup_bam_file, $normal_common_name, $normal_type, $normal_build->whole_rmdup_bam_file;
#	printf "%s %s: %s\n%s %s: %s\n",$tumor_common_name, $tumor_type, $tumor_datadir, $normal_common_name, $normal_type,$normal_datadir;

    }
    return 1;

}

1;

#    if($self->common_name){
#        my @m = Genome::Model->get(subject_id => $common_name, 	subject_class_name => Sample);
#    }

sub help_brief {
	"Retrive the directory of builds";
}

sub help_detail {
    	<<'HELP';
This dumps the filtered.snps file locations for the tumor and normal builds used in somatic models
HELP
}
