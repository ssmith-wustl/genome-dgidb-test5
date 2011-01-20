package Genome::Model::Tools::DetectVariants2::Base;

use strict;
use warnings;

use Clone qw/clone/;
use Data::Compare;
use Data::Dumper;
use Genome;

class Genome::Model::Tools::DetectVariants2::Base {
    is => ['Genome::Command::Base'],
    has_optional => [
        snv_detection_strategy => {
            is => "Genome::Model::Tools::DetectVariants2::Strategy",
            doc => 'The variant detector strategy to use for finding SNVs',
        },
        indel_detection_strategy => {
            is => "Genome::Model::Tools::DetectVariants2::Strategy",
            doc => 'The variant detector strategy to use for finding indels',
        },
        sv_detection_strategy => {
            is => "Genome::Model::Tools::DetectVariants2::Strategy",
            doc => 'The variant detector strategy to use for finding SVs',
        },
    ],
    has_constant => [
        variant_types => {
            is => 'ARRAY',
            value => [('snv', 'indel', 'sv')],
        },
        #These can't be turned off--just pass no detector name to skip
        detect_snvs => { value => 1 },
        detect_indels => { value => 1 },
        detect_svs => { value => 1 },
    ],
    doc => 'This is the base class for all detect variants classes and the variant detector dispatcher',
};

sub help_brief {
    "The base class for variant detectors.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
This is just an abstract base class for variant detector modules.
EOS
} 

sub help_detail {
    return <<EOS 
This is just an abstract base class for variant detector modules.
EOS
}

sub _should_skip_execution {
    my $self = shift;
    
    for my $variant_type (@{ $self->variant_types }) {
        my $name_property = $variant_type . '_detection_strategy';
        
        return if defined $self->$name_property;
    }
    
    $self->status_message('No variant detectors specified.');
    return $self->SUPER::_should_skip_execution;
}


