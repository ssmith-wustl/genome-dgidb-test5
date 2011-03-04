package Genome::Model::Tools::Music;
use strict;
use warnings;
use Genome;
our $VERSION = '0.01';

class Genome::Model::Tools::Music {
    is => ['Command::Tree'],
    doc => 'identify mutations of significance in cancer'
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
    return Genome::Model::Tools->doc_copyright_license;
}

sub doc_manual {
    # place POD for content which should ONLY be in the cross-tool manual page
    return <<EOS

EOS
}

sub doc_credits {
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

