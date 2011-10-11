package Genome::Subject::Command::Import;

use strict;
use warnings;

use Genome;

class Genome::Subject::Command::Import {
    is => 'Command',
    has => [
       nomenclature => { is => 'Text' },
       subclass_name => { is => 'Text' },
       content => { is => 'Text' }
    ],
};

sub help_brief {
    return 'Import subjects via web interface';
}

sub execute {
    warn "YEAH EXECUTE";
}

1;

