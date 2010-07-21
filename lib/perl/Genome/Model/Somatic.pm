package Genome::Model::Somatic;
#:adukes short term, keep_n_most_recent_builds shouldn't have to be overridden like this here.  If this kind of default behavior is acceptable, it belongs in the base class

use strict;
use warnings;

use Genome;

class Genome::Model::Somatic {
    is  => 'Genome::Model',
    has => [
       only_tier_1 => { via => 'processing_profile'},
       min_mapping_quality => { via => 'processing_profile'},
       min_somatic_quality => { via => 'processing_profile'},
       skip_sv => { via => 'processing_profile'},
       require_dbsnp_allele_match => { via => 'processing_profile'},
       sv_detector_params => { via => 'processing_profile'},
       sv_detector_version => { via => 'processing_profile'},
       bam_window_params => { via => 'processing_profile'},
       bam_window_version => { via => 'processing_profile'},
       sniper_params => { via => 'processing_profile'},
       sniper_version => { via => 'processing_profile'},
       bam_readcount_params => { via => 'processing_profile'},
       bam_readcount_version => { via => 'processing_profile'},
    ],
    has_optional => [
         tumor_model_links                  => { is => 'Genome::Model::Link', reverse_as => 'to_model', where => [ role => 'tumor'], is_many => 1,
                                               doc => '' },
         tumor_model                     => { is => 'Genome::Model', via => 'tumor_model_links', to => 'from_model', 
                                               doc => '' },
         normal_model_links                  => { is => 'Genome::Model::Link', reverse_as => 'to_model', where => [ role => 'normal'], is_many => 1,
                                               doc => '' },
         normal_model                     => { is => 'Genome::Model', via => 'normal_model_links', to => 'from_model', 
                                               doc => '' },
    ],
};


# we get a failure during verify successful completion
# if we don't have this...
sub keep_n_most_recent_builds
{
    my $self = shift;
    return;
}

1;
