package Genome::ProcessingProfile::PooledAssemblyDecomposition;

use strict;
use warnings;
use Genome;

class Genome::ProcessingProfile::PooledAssemblyDecomposition {
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
        }
    ],
    has_param => [
        percent_overlap => 
        {
            type => 'String',
            is_optional => 1,
            doc => "this is the percent overlap, default is 50%",
        },
        percent_identity =>
        {
            type => 'String',
            is_optional => 1,
            doc => "this is the percent identity, default is 85%",
        },
        blast_params =>
        {
            type => 'String',
            is_optional => 1,
            doc => "Use this option to override the default blast params, the default param string is:\n M=1 N=-3 R=3 Q=3 W=30 wordmask=seg lcmask hspsepsmax=1000 golmax=0 B=1 V=1 topcomboN=1 -errors -notes -warnings -cpus 4 2>/dev/null",        
        }, 
    ],
    doc => "Processing Profile for the Pooled Assembly Decomposition Pipeline"
};

sub _execute_build {
    my ($self,$build) = @_;
    my $pooled_assembly_model = $build->model->from_models;
    
    my $pooled_assembly_build = $pooled_assembly_model->last_complete_build;
    unless ($pooled_assembly_build) {
        $self->error_message("Underlying model " . $pooled_assembly_model->__display_name__ . " has no complete builds!");
        return;
    }
    
    unless ($build->add_from_build(from_build => $pooled_assembly_build, role => 'pooled assembly')) {
        Carp::confess("Failed link pooled assembly build!");
    }
    
    my $pooled_assembly_build_directory = $pooled_assembly_build->data_directory;
    unless ($pooled_assembly_build_directory && -e $pooled_assembly_build_directory) {
        my $msg = $self->error_message("Failed to get last complete build directory for the input pooled assembly!");
        Carp::confess($msg);
    }
   
    print "Executing pooled assembly decomposition build.\n";
    
    my @inputs = $build->inputs;

    my $data_directory = $build->data_directory;
    my $percent_identity = $self->percent_identity;
    my $percent_overlap = $self->percent_overlap;
    my $pooled_assembly_dir = $pooled_assembly_build_directory;
    my $blast_params = $self->blast_params;
    
    my %params = map {$_->name ,$_->value_id;} @inputs;
    
    return Genome::Model::Tools::PooledBac::Run->execute(
        project_dir => $data_directory, 
        pooled_bac_dir => $pooled_assembly_dir, 
        percent_identity => $percent_identity, 
        percent_overlap => $percent_overlap, 
        blast_params => $blast_params,
        
        #ref_seq_file   required, get later from db? 
        #ace_file_name  optional override
        #phd_ball_name  optional override
        %params,
    );
}

1;

