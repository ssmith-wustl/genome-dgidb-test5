#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 2;


BEGIN {use_ok('Genome::Model::Tools::ViromeEvent::SequenceQualityControl');}

#create
my $sqc = Genome::Model::Tools::ViromeEvent::SequenceQualityControl->create(
                                                                dir        => '/gscmnt/sata835/info/medseq/virome/test17',
                                                            );
isa_ok($sqc, 'Genome::Model::Tools::ViromeEvent::SequenceQualityControl');
#$sqc->execute();
