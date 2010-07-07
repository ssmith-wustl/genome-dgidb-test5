package Genome::Model::Tools::BioSamtools;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::BioSamtools {
    is => ['Command'],
    is_abstract => 1,
};

sub help_detail {
    "These commands are setup to run perl5.10.0 scripts that use Bio-Samtools and require bioperl v1.6.0.  Most require 64-bit architecture except those that simply work with output files from other Bio-Samtools commands.";
}

sub perl_path {
    return '/gsc/var/tmp/perl-5.10.0/bin/perl64';
}

sub bin_path {
    return '/gsc/var/tmp/Bio-SamTools/bin';
    #TESTING-ONLY
    #return '/gscuser/jwalker/svn/TechD/Bio-SamTools/bin';
}

sub execute_path {
    my $self = shift;
    return $self->perl_path .' '. $self->bin_path;
}

sub bioperl_path {
    return '/gsc/pkg/perl_modules/bioperl/BioPerl-1.6.0';
}

1;
