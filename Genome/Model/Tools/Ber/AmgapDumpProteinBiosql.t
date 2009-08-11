#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use File::Remove qw/ remove /;

use Test::More tests => 3;

BEGIN {
    use_ok('Genome::Model::Tools::Ber::AmgapDumpProteinBiosql');
    
}

my $tool_db = Genome::Model::Tools::Ber::AmgapDumpProteinBiosql->create(
                    'locus_tag'       => "PNI0002DFT",

		);
isa_ok($tool_db,'Genome::Model::Tools::Ber::AmgapDumpProteinBiosql');


ok($tool_db->execute,'execute amgapdumpproteinbiosql');
