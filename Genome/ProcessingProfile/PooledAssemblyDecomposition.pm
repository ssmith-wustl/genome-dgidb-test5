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
        #these params should become inputs
#        pooled_assembly => { 
#            is => 'Genome::Model',
#            id_by => 'from_assembly', 
#            doc => 'The input pooled assembly' 
#        },
        pooled_assembly_dir => 
        {
            type => 'String',
            is_optional => 0,
            doc =>  'The input pooled assembly' 
        },
        ref_seq_file =>
        {
            type => 'String',
            is_optional => 0,
            doc => "location of the reference sequence"        
        },
        ace_file_name =>
        {
            type => 'String',
            is_optional => 1,
            doc => "name of ace file, if different than Pcap.454Contigs.ace.1"        
        },
        phd_ball_name =>
        {
            type => 'String',
            is_optional => 1,
            doc => "name of phdball if different than phd.ball.1"        
        },    
    ],
    doc => "Processing Profile for the Pooled Assembly Decomposition Pipeline"
};

#sub stages {
#    return (qw/ pooled_assembly_decomposition /);
#}
#
#sub pooled_assembly_decomposition_objects {
#    return 1;
#}
#
#sub pooled_assembly_decomposition_job_classes {
#    return (qw/
#               Genome::Model::Event::Build::PooledAssembly::RunBlast;
#               Genome::Model::Event::Build::PooledAssembly::MapContigsToAssembly;
#               Genome::Model::Event::Build::PooledAssembly::AddLinkingContigs;
#               Genome::Model::Event::Build::PooledAssembly::GenerateReports;
#               Genome::Model::Event::Build::PooledAssembly::CreateProjectDirectories;
#               Genome::Model::Event::Build::PooledAssembly::GeneratePostAssemblyReports;
#            /);
#}

sub _execute_build {
    my ($self,$build) = @_;
    
    print "hello world.\n";
    my $data_directory = $build->data_directory;
    my $percent_identity = $self->percent_identity;
    my $percent_overlap = $self->percent_overlap;
    my $ref_seq_file = $self->ref_seq_file;
    my $pooled_assembly_dir = $self->pooled_assembly_dir;
    my $blast_params = $self->blast_params;
    my $ace_file_name = $self->ace_file_name;
    my $phd_ball_name = $self->phd_ball_name;
    
    
    #print "inputs are ",join (@inputs,','),"\n";
    return Genome::Model::Tools::PooledBac::Run->execute(project_dir => $data_directory, 
                                                                                      pooled_bac_dir => $pooled_assembly_dir, 
                                                                                      percent_identity => $percent_identity, 
                                                                                      percent_overlap => $percent_overlap, 
                                                                                      ref_seq_file => $ref_seq_file, 
                                                                                      blast_params => $blast_params,
                                                                                      ace_file_name => $ace_file_name,
                                                                                      phd_ball_name => $phd_ball_name,
                                                                                      );
}

1;

