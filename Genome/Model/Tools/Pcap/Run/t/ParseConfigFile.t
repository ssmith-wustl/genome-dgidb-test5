use strict;
use warnings;

use Workflow;

use Test::More tests => 3;


BEGIN {
    use_ok('Genome::Model::Tools::Pcap::Run::ParseConfigFile');
}

my $command = Genome::Model::Tools::Pcap::Run::ParseConfigFile->create(
                                                                                 config_file => '/dev/null' 
                                                                                );

isa_ok($command, 'Genome::Model::Tools::Pcap::Run::ParseConfigFile');

ok($command->execute(), 'execute');

