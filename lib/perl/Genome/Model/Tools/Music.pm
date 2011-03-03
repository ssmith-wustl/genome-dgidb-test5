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
        'Dan Koboldt',
        'William Scheirding, Ph.D.',
        'Michael Wendl, Ph.D.',
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

1;

