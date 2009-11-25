package Genome::Model::Tools::BioSamtools;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::BioSamtools {
    is => ['Command'],
    is_abstract => 1,
};

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
