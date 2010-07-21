package Genome::Model::Tools::Somatic::Compare;

use strict;
use warnings;

use Genome;
use File::Basename;

class Genome::Model::Tools::Somatic::Compare {
    is => 'Command',
};

sub help_brief {
    "Tools to run the comparison of tumor and normal models.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt somatic compare  ...    
EOS
}

sub help_detail {                           
    return <<EOS 
Tools to run the comparison of tumor and normal models.
EOS
}



1;

