#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
require IO::File;
use Test::More;

use_ok('Genome::Utility::IO::StdoutRefWriter') or die;
my $writer = Genome::Utility::IO::StdoutRefWriter->create();
ok($writer, 'Created writer');
can_ok($writer, 'write');

use_ok('Genome::Utility::IO::StdinRefReader') or die;
my $reader = Genome::Utility::IO::StdinRefReader->create();
ok($reader, 'Created reader');
can_ok($reader, 'read');
can_ok($reader, 'next');

my $fh = IO::File->new(qq{ perl -Mstrict -M'above "Genome"' -MGenome::Utility::IO::StdoutRefWriter  -e 'Genome::Utility::IO::StdoutRefWriter->write(UR::Value->get(100));' |  perl -Mstrict -M'above "Genome"' -MGenome::Utility::IO::StdinRefReader -e 'my \$ref = Genome::Utility::IO::StdinRefReader->read or die; print \$ref->id."\n";' | });
ok($fh, 'Created pipe') or die;
my $value = $fh->getline;
$fh->close;
chomp $value;
is($value, 100, 'Write object to STDIN, read object from STDOUT, got correct value');

done_testing();
exit;

#########

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2006 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Utility/IO/Reader.t $
#$Id: Reader.t 43282 2009-02-04 22:10:21Z ebelter $

