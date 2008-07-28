use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;

use File::Temp;
use Test::More tests => 8;

BEGIN {
    use_ok('BAP::Command');
    use_ok('BAP::Command::InterProScan');
}

my $command = BAP::Command::BuildGlimmerInput->create('fasta_files' => [ 'data/HPAG1.fasta' ]);
isa_ok($command, 'BAP::Command::BuildGlimmerInput');

ok($command->execute());

my $model_file = $command->model_file();
my $pwm_file   = $command->pwm_file();

ok(-e $model_file);
ok(-e $pwm_file);

ok(unlink($model_file)==1);
ok(unlink($pwm_file)==1);
