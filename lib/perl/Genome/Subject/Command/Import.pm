package Genome::Subject::Command::Import;

use strict;
use warnings;

use Genome;
use MIME::Types;


class Genome::Subject::Command::Import {
    is => 'Command',
    has => [
       nomenclature_id => { is => 'Text' },
       nomenclature    => { is => 'Genome::Nomenclature', id_by=>'nomenclature_id' },
       nomenclature_name    => { is => 'Text', via=>'nomenclature', to=>'name' },
       subclass_name   => { is => 'Text' },
       content => { is => 'Text' }
    ],
};

sub help_brief {
    # xls or csv
    return 'Import subjects via web interface';
}

sub execute {
    warn "YEAH EXECUTE";
}

1;

