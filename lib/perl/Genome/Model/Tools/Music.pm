package Genome::Model::Tools::Music;
use strict;
use warnings;
use Genome;
our $VERSION = '0.01';

class Genome::Model::Tools::Music {
    is => ['Command::Tree'],
    doc => 'MuSiC: identify mutations of significance in cancer'
};

sub doc_authors {
    return (
        'Nathan Dees Ph.D.',
        'Cyriac Kandoth, Ph.D.',
        'Dan Koboldt, M.S.',
        'William Schierding, M.S.',
        'Michael Wendl, Ph.D.',
        'Qunyuan Zhang, Ph.D.',
    );
}

sub doc_copyright_years {
    (2007,2011);
}

sub doc_copyright_license {
    my $self = shift;
    my (@y) = $self->doc_copyright_years;  
    return <<EOS
    Copyright (C) $y[0]=$y[1] Washington University in St. Louis.

    It is released under the Lesser GNU Public License (LGPL) version 3.  See the 
    associated LICENSE file in this distribution.
EOS
}

sub doc_support {   
    return <<EOS;
   For defects with any software in the genome namespace,
   contact gmt ~at~ genome.wustl.edu.
EOS
}

sub doc_manual {
    # TODO: place POD for content which should ONLY be in the cross-tool manual page
    return <<EOS
EOS
}

sub doc_credits {
    # TODO: update this with URLs and more clarity
    return <<EOS
The MuSiC suite uses tabix, by Heng Li.  See http://...

MuSiC depends on copies of data from the following databases, converted into a form useable for quick analysis:
* COSMIC
* OMIM
* GenBank
* EnsEMBL
EOS
}

1;

