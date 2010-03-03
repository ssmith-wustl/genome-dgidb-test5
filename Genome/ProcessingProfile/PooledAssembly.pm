package Genome::ProcessingProfile::PooledAssembly;

use strict;
use warnings;
use Genome;

class Genome::ProcessingProfile::PooledAssembly {
    is => 'Genome::ProcessingProfile',
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
    doc => "Processing Profile for the Pooled Assembly Pipeline"
};

sub _execute_build {
    my ($self,$build) = @_;
    warn "executing build logic for " . $self->__display_name__ . ':' .  $build->__display_name__ . "\n";

    #return Genome::Model::Tools::PooledBac::Run(;
    return 1;
}



1;

