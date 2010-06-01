
use strict;
use warnings;

use Test::More tests => 9;
use Test::Output;
use Test::Exception;

use Data::Dumper;
use Cwd;
use File::Basename;

use above 'Genome';
BEGIN { use_ok('Genome::Model::Tools::LSFSpool') };

my $thisfile = Cwd::abs_path(__FILE__);
my $cwd = dirname $thisfile;

sub test_logger {
  my $obj = create Genome::Model::Tools::LSFSpool;
  $obj->{configfile} = $cwd . "/data/lsf_spool_sleep.cfg";
  $obj->{debug} = 0;
  $obj->prepare_logger();
  $obj->read_config();
  $obj->activate_suite();
  # Test enable debugging
  $obj->{debug} = 1;
  stdout_like { $obj->{suite}->logger("Test\n"); } qr/Test/, "logger with debug on ok";
  stdout_like { $obj->{suite}->local_debug("Test\n"); } qr/Test/, "debug on ok";
  # Test disable debugging
  $obj->{debug} = 0;
  stdout_like { $obj->{suite}->logger("Test\n"); } qr/Test/, "logger with debug off ok";
  $obj->{suite}->local_debug("Test\n");
  stdout_unlike { $obj->{suite}->local_debug("Test\n"); } qr/Test/, "debug off ok";
}

sub test_activate_suite {
  # test activate suite, the Sleep one.
  my $dir = $cwd . "/data/spool/sample-fasta-1";
  my $file = "sample-fasta-1-1";
  my $obj = create Genome::Model::Tools::LSFSpool;
  $obj->{configfile} = $cwd . "/data/lsf_spool_sleep.cfg";
  $obj->{debug} = 0;
  $obj->prepare_logger();
  $obj->read_config();
  $obj->activate_suite();
  is($obj->{config}->{suite}->{name},"Sleep");
  my $command = $obj->{suite}->action($dir,$file);
  like($command,qr|^sleep 5|,"comamnd returned ok");
  stdout_like { $obj->{suite}->logger("test\n") } qr/test/, "stdout logs 'test' ok";
  ok($obj->{suite}->is_complete("$dir/$file") == 0,"is_complete returns false ok");
}

sub test_submit_job {

  my $obj = create Genome::Model::Tools::LSFSpool;

  $obj->{configfile} = $cwd . "/data/lsf_spool_sleep.cfg";
  $obj->{debug} = 1;
  $obj->prepare_logger();
  $obj->read_config();
  # Sleep a long time...
  $obj->{config}->{suite}->{parameters} = 1;
  $obj->activate_suite();
  $obj->find_progs();

  $obj->{config}->{queue} = "short";

  my $path = $cwd . "/data/spool/sample-fasta-1";
  my $file = "sample-fasta-1-1";

  # bsub job and wait for it.

  my $id = $obj->submit_job("$path/$file");
  ok($id > 0,"bsub submits job id $id");

  $obj->DESTROY();
}

test_logger();
test_activate_suite();

# This test is really only useful interactively, not automated
#test_submit_job();
