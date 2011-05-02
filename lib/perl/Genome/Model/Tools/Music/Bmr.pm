package Genome::Model::Tools::Music::Bmr;
use warnings;
use strict;
use Genome;

our $VERSION = $Genome::Model::Tools::Music::VERSION; 

class Genome::Model::Tools::Music::Bmr {
    is  => ['Command::Tree','Genome::Model::Tools::Music::Base'],
    doc => "calculate gene coverages and background mutation rates"
};

sub _doc_copyright_years {
    (2010,2011);
}

sub _doc_license {
    my $self = shift;
    my (@y) = $self->_doc_copyright_years;  
    return <<EOS
Copyright (C) $y[0]-$y[1] Washington University in St. Louis.

It is released under the Lesser GNU Public License (LGPL) version 3.  See the 
associated LICENSE file in this distribution.
EOS
}


sub _doc_authors {
    return ('',
        'Cyriac Kandoth, Ph.D.'
    );
}

sub _doc_credits {
    # used to compose man pages 
    # (return a list of strings)
    return ('','None at this time.');
}

sub _doc_see_also {
    return ('','B<genome-music>(1)','B<genome>(1)')
}

sub _doc_manual_body {
    return shift->help_detail;
}

sub help_detail { 
    return "This tool is part of the MuSiC suite. See:\n"
    . join("\n",shift->_doc_see_also)
    . "\n";
}

1;
