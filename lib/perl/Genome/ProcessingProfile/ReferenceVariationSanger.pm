package Genome::ProcessingProfile::ReferenceVariationSanger;

use strict;
use warnings;
use Genome;

class Genome::ProcessingProfile::ReferenceVariationSanger {
    is => 'Genome::ProcessingProfile',
    has => [
        server_dispatch => {
            is_constant => 1,
            is_class_wide => 1,
            value => 'inline',
            doc => 'lsf queue to submit the launcher or \'inline\''
        },
        job_dispatch => {
            is_constant => 1,
            is_class_wide => 1,
            value => 'inline',
            doc => 'lsf queue to submit jobs or \'inline\' to run them in the launcher'
        },
    ],
    has_param => [

	mail_me => {
	    type  =>  'Boolean',
            doc  => 'optional; default no mail; use mail-me option to get mailed when the analysis is complete',
    	    is_optional  => 1,
	},
	lsf_memory_requirement => {
            type  =>  'String',
            doc  => "optional provide gigs of resource to reserve for your lsf job as a number from 4 to 8; Default is 4",
	    is_optional  => 1,
	},
	poly_source_1 => {
            type  =>  'String',
            doc  => 'optional; default is 1; poly-source-1 sets start of grouping of traces within a sample to be evaluated',
   	    is_optional  => 1,
        },
	poly_source_2 => {
            type  =>  'String',
            doc  => 'optional; default is 20; poly-source-2 sets stop of grouping of traces within a sample to be evaluated',
    	    is_optional  => 1,
	},
	poly_indel_source_1 => {
            type  =>  'String',
            doc  => 'optional; default is 1; poly-indel-source-1 sets start of grouping of traces within a sample to be evaluated',
   	    is_optional  => 1,
	},
	poly_indel_source_2 => {
            type  =>  'String',
            doc  => 'optional; default is 2; poly-indel-source-2 sets stop of grouping of traces within a sample to be evaluated',
    	    is_optional  => 1,
	},
	pretty_source_1 => {
            type  =>  'String',
            doc  => 'optional; default is 1; pretty-source-1 defines the start boundary of a sample name',
    	    is_optional  => 1,
	},
	pretty_source_2 => {
            type  =>  'String',
            doc  => 'optional; default is 20; pretty-source-2 defines the end boundary of a sample name',
    	    is_optional  => 1,
	},
    ],
    doc => "runs gmt analysis auto-msa"
};

sub _execute_build {
     my ($self, $build) = @_;
     warn "executing build logic for " . $self->__display_name__ . ':' .  $build->__display_name__ . "\n";
     my $dir = $build->data_directory;


     my $model = $build->model;

     unless ($model){
	 $self->error_message("Couldn't find model for id ". $self->model_id);
	 return;
     }

     $self->status_message("Found Model: " . $model->name);

     my @inputs = $build->inputs();
     unless (@inputs) {$self->error_message("Couldn't find the inputs model for id ". $self->model_id);return;}
     my %input = map {$_->name,$_->value_id;} @inputs;

     my $ace_fof = $input{ace_fof};
     unless ($ace_fof) {$self->error_message("Couldn't find the ace_fof model for id ". $self->model_id);return;}

     my $linked = &link_dirs($dir,$ace_fof,$self);

     unless ($linked) {
	 print qq(couldn't link in the project dirs to the data_dir\n);
	 return;
     }

     my %params = map { $_->name => $_->value } $self->params;
     my $result = Genome::Model::Tools::Analysis::AutoMsa->execute(%params,%input);

     if ($result) {
	 print qq(you're analysis has been executed\n);
	 return $result;
     } else {
	 print qq(you're analysis has failed to execute\n);
	 return;
     }
}

sub _validate_build {
    my $self = shift;
    my $dir = $self->data_directory;
    
    my @errors;
    unless (-e "$dir/output") {
        my $e = $self->error_message("No output file $dir/output found!");
        push @errors, $e;
    }
    unless (-e "$dir/errors") {
        my $e = $self->error_message("No output file $dir/errors found!");
        push @errors, $e;
    }

    if (@errors) {
        return;
    }
    else {
        return 1;
    }
}

sub link_dirs {

    use File::Copy;

    my ($dir,$ace_fof,$self) = @_;
    unless (-f $ace_fof) { return; }
    unless (-d $dir) { return; }

    my $working_dir = `pwd`;
    chdir $dir;
    my $n = 0;
    open (FOF,$ace_fof) || $self->error_message("Couldn't open the ace_fof $ace_fof") && return;
    copy ($ace_fof,$dir) || $self->error_message("Couldn't copy the ace_fof $ace_fof to the build directory $dir");

    while (<FOF>) {
	chomp;
	my $ace = $_;
	my ($project_dir_path) = (split(/\/edit_dir/,$ace))[0];
	my ($project_dir) = (split(/\//,$project_dir_path))[-1];
	
	symlink($project_dir_path, $project_dir);

	if ("$dir/$project_dir") { $n++; }
	
    }
    close FOF;
    chdir $working_dir;
    return $n;
}

1;

