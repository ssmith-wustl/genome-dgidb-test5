use strict;
use warnings;

use Workflow;

use Test::More tests => 3;


BEGIN {
    use_ok('Genome::Model::Tools::AssembleReads::Pcap::ParseConfigFile');
}

my $command = Genome::Model::Tools::AssembleReads::Pcap::ParseConfigFile->create(
                                                                                 config_file => '/dev/null' 
                                                                                );

isa_ok($command, 'Genome::Model::Tools::AssembleReads::Pcap::ParseConfigFile');

ok($command->execute(), 'execute');

