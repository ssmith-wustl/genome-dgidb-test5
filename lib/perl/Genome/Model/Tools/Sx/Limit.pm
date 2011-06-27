package Genome::Model::Tools::Sx::Limit;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Tools::Sx::Limit {
    is  => 'Genome::Model::Tools::Sx',
    is_abstract => 1,
};

sub help_brief {
    return <<HELP
    Limit fastq and fasta/quality sequences
HELP
}

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Tools/Fastq/Base.pm $
#$Id: Base.pm 60817 2010-07-09 16:10:34Z ebelter $
