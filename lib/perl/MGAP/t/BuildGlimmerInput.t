use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;

use File::Temp;
use Test::More tests => 15;

BEGIN {
    use_ok('MGAP::Command');
    use_ok('MGAP::Command::BuildGlimmerInput');
}

my $command = MGAP::Command::BuildGlimmerInput->create('fasta_files' => [ 'data/HPAG1.fasta' ]);
isa_ok($command, 'MGAP::Command::BuildGlimmerInput');

ok($command->execute());

my $model_file = $command->model_file();
my $model_size = -s $model_file;
my $pwm_file   = $command->pwm_file();

ok(-e $model_file);
is($model_size, 1388532);
ok(-e $pwm_file);

ok(unlink($model_file)==1);
ok(unlink($pwm_file)==1);

$command = MGAP::Command::BuildGlimmerInput->create('fasta_files' => ['data/BIFCATDFT.fasta' ]);

ok($command->execute());

$model_file = $command->model_file();
$model_size = -s $model_file;
$pwm_file   = $command->pwm_file();

ok(-e $model_file);
is($model_size, 1441684);
ok(-e $pwm_file);

ok(unlink($model_file)==1);
ok(unlink($pwm_file)==1);

