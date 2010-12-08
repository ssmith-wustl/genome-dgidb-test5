package Genome::Model::Tools::Xhong::RunCnvQc;

use strict;
use warnings;

use Genome;
use IO::File;


class Genome::Model::Tools::Xhong::RunCnvQc {
	is => 'Command',
	has => [
    	model_group_name => { type => 'String', is_optional => 0, doc => "name of the model group to process", },
        analysis_dir => { type => 'String', is_optional => 0, doc => "Directory where the lane-by-lane CNV QC output will be", },
        ]
};

sub help_brief {
    	"Run lane-by-lane CNV QC for all the last succeed builds in a model-groups"
}

sub help_detail {
    	<<'HELP';
Hopefully this script run ks filter on the last succeed somatic builds in a model group
HELP
}

sub execute {
	my $self=shift;
    	$DB::single = 1;
    	
    	my $analysis_dir=$self->analysis_dir;
    	my @models;
    	my $group = Genome::ModelGroup->get(name => $self->model_group_name);
    	unless($group) {
    	    $self->error_message("Unable to find a model group named " . $self->model_group);
    	    return;
    	}
    	push @models, $group->models;
 	
    	foreach my $model (@models) {
    		my $subject_name = $model->subject_name;
 #   print "$subject_name\t";
        	unless($model->type_name eq 'somatic') {
            		$self->error_message("This build must be a somatic pipeline build");
            		return;
        	}

	        my $build = $model->last_succeeded_build;
	        unless (defined($build)) {
        		$self->error_message("Unable to find succeeded build for model ".$model->id);
        		return; #next;
        	}
        	my $model_id = $build->model_id;
        	my $build_id = $build->build_id;
		my $tumor_build_id=$build->tumor_build->build_id;
		my $normal_build_id=$build->normal_build->build_id;
        	my $common_name = $build->tumor_build->model->subject->source_common_name;
		my $tumor_model_id=$build->tumor_build->model_id;
		my $normal_model_id=$build->normal_build->model_id;
#		my $tumor_model_id=$model->tumor_model->build->model_id;
#		my $normal_model_id=$model->normal_model->build->model_id;
#		my $common_name =$model->normal_model->subject->source_common_name;
		print "T: $tumor_model_id\t N: $normal_model_id\n";

		my $user = getlogin || getpwuid($<); #get current user name
		my $out_dir=$analysis_dir."/".$common_name."/";
		my $tumor_dir=$out_dir."/tumor/";
		my $normal_dir=$out_dir."/normal/";
		
# check whether the directory can be created or already exists		
		unless (-d "$out_dir"){
           		system ("mkdir -p $tumor_dir");
           		system ("mkdir -p $normal_dir");
            	}
            	print "$common_name\n";
            	my $cmd ="bsub -N -u $user\@genome.wustl.edu -J $common_name.CNVQC -R \'select\[type==LINUX64\]\' \'gmt xhong compare-cnv-build-lanes --outfile-prefix=$out_dir/tumor --model-id=$tumor_model_id\'";
            	print "$cmd\n";
#            	system($cmd);
		$cmd ="bsub -N -u $user\@genome.wustl.edu -J $common_name.CNVQC -R \'select\[type==LINUX64\]\' \'gmt analysis lane-qc copy-number --outfile-prefix=$out_dir/normal --model-id=$normal_model_id\'";
            	print "$cmd\n";
#		system($cmd);
            	
    	} # finish of all sample (somatic models)

        return 1;
}


1;


