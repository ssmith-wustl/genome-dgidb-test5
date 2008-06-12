use strict;
use warnings;

use Workflow;

use File::Temp;
use Test::More tests => 9;

BEGIN {
    use_ok('MGAP::Command');
    use_ok('MGAP::Command::DeleteFastaFiles');
}

my @files = ( 
              File::Temp->new('UNLINK' => 0)->filename(),
              File::Temp->new('UNLINK' => 0)->filename(),
              File::Temp->new('UNLINK' => 0)->filename(),
              File::Temp->new('UNLINK' => 0)->filename(),
              File::Temp->new('UNLINK' => 0)->filename(),
            );

my $command = MGAP::Command::DeleteFastaFiles->create('fasta_files' => \@files);
isa_ok($command, 'MGAP::Command::DeleteFastaFiles');

ok($command->execute());

foreach my $file (@files) {
    ok(! -e $file);
}

