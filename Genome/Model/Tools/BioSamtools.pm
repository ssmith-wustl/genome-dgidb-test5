package Genome::Model::Tools::BioSamtools;

use strict;
use warnings;

use Genome;

my $DEFAULT_LSF_QUEUE = 'long';
my $DEFAULT_LSF_RESOURCE = "-R 'select[type==LINUX64]'";

class Genome::Model::Tools::BioSamtools {
    is => ['Command'],
    is_abstract => 1,
    has_param => [
        lsf_queue => {
            is_optional => 1,
            default_value => $DEFAULT_LSF_QUEUE,
            doc => 'The lsf queue to run jobs in when run in parallel. default_value='. $DEFAULT_LSF_QUEUE,
        },
        lsf_resource => {
            is_optional => 1,
            default_value => $DEFAULT_LSF_RESOURCE,
            doc => 'The lsf resource request necessary to run in parallel.  default_value='. $DEFAULT_LSF_RESOURCE,
        },
    ],
};

sub help_detail {
    "These commands are setup to run perl5.10.0 scripts that use Bio-Samtools and require bioperl v1.6.0.  They all require 64-bit architecture.";
}

sub perl_path {
    return '/gsc/var/tmp/perl-5.10.0/bin/perl64';
}

sub bin_path {
    return '/gsc/var/tmp/Bio-SamTools/bin';
}

sub execute_path {
    my $self = shift;
    return $self->perl_path .' '. $self->bin_path;
}

sub bioperl_path {
    return '/gsc/pkg/perl_modules/bioperl/BioPerl-1.6.0';
}

1;
