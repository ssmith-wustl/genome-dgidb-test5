#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Test::More;

use_ok('Genome::InstrumentData::Command::Dacc::UpdateLibrary') or die;

my $dir = '/gsc/var/cache/testsuite/data/Genome-InstrumentData-Command-Dacc/SRS000000';
my @xml_files = glob($dir.'/*xml');
is(@xml_files, 2, 'Got 2 xml files');
my $update_lib = Genome::InstrumentData::Command::Dacc::UpdateLibrary->create(
    sra_sample_id => 'SRS000000',
    xml_files => \@xml_files,
);
ok($update_lib, 'create');
ok($update_lib->execute, 'execute');

done_testing();
exit;

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2010 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

