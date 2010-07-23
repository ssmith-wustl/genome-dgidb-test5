use strict;
use warnings;

use above "MGAP";
use Workflow;

use File::Temp;
use Test::More tests => 9;

BEGIN {
    use_ok('MGAP::Command');
    use_ok('MGAP::Command::DeleteFiles');
}

my @files = ( 
              File::Temp->new('UNLINK' => 0)->filename(),
              File::Temp->new('UNLINK' => 0)->filename(),
              File::Temp->new('UNLINK' => 0)->filename(),
              File::Temp->new('UNLINK' => 0)->filename(),
              File::Temp->new('UNLINK' => 0)->filename(),
            );

my $command = MGAP::Command::DeleteFiles->create('fasta_files' => \@files);
isa_ok($command, 'MGAP::Command::DeleteFiles');

ok($command->execute());

foreach my $file (@files) {
    ok(! -e $file);
}

