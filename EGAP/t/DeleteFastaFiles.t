use strict;
use warnings;

use above 'EGAP';

use File::Temp;
use Test::More tests => 9;

BEGIN {
    use_ok('EGAP::Command');
    use_ok('EGAP::Command::DeleteFiles');
}

my @files = ( 
              File::Temp->new('UNLINK' => 0)->filename(),
              File::Temp->new('UNLINK' => 0)->filename(),
              File::Temp->new('UNLINK' => 0)->filename(),
              File::Temp->new('UNLINK' => 0)->filename(),
              File::Temp->new('UNLINK' => 0)->filename(),
            );

my $command = EGAP::Command::DeleteFiles->create('files' => \@files);
isa_ok($command, 'EGAP::Command::DeleteFiles');

ok($command->execute());

foreach my $file (@files) {
    ok(! -e $file);
}

