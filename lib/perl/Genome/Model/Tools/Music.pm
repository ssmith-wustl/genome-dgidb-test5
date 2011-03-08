package Genome::Model::Tools::Music;
use strict;
use warnings;
use Genome;
our $VERSION = '0.01';

class Genome::Model::Tools::Music {
    is => ['Command::Tree'],
    doc => 'MuSiC: identify mutations of significance in cancer'
};

sub _doc_manual_body {
    return <<EOS
The MuSiC suite is a set of tools to analyze mutations in MAF format, with respect
to a variety of external data sources.

The B<play> command runs all of the tools serially on a selected input set.
EOS
}

sub _doc_copyright_years {
    (2007,2011);
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
    return (
        <<EOS,
This software is developed by the analysis and engineering teams at 
The Genome Institute at Washington University School of Medicine in St. Louis,
with funding from the National Human Genome Research Institute.  Richard K. Wilson, P.I.

The primary authors of the MuSiC suite are:
EOS
        'Nathan Dees, Ph.D.',
        'Cyriac Kandoth, Ph.D.',
        'Dan Koboldt, M.S.',
        'William Schierding, M.S.',
        'Michael Wendl, Ph.D.',
        'Qunyuan Zhang, Ph.D.',
    );
}


sub _doc_bugs {   
    return <<EOS;
For defects with any software in the genome namespace, contact
 genome-dev ~at~ genome.wustl.edu.
EOS
}

sub _doc_credits {
    # TODO: update this with URLs and more clarity
    return (
        <<EOS,
The MuSiC suite uses tabix, by Heng Li.  See http://...

MuSiC depends on copies of data from the following databases, packaged in a form useable for quick analysis:
EOS
        "* COSMIC",
        "* OMIM",
        "* GenBank",
        "* EnsEMBL",
    );
}

sub _doc_see_also {
    'B<genome>(1)',
}

1;

