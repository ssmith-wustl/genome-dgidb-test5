package Genome::Model::Tools::AssembleReads::Pcap::ParseConfigFile;

use strict;
use warnings;

use lib '/gscuser/kkyung/svn/pm';

use Workflow;
use IO::File;
use above "Genome";
use Data::Dumper;


class Genome::Model::Tools::AssembleReads::Pcap::ParseConfigFile
{
    is => 'Command',
    has => [
	        config_file      => {type => 'String', doc => "configuration file"},
	        disk_location    => {type => 'String', is_optional => 1, doc => "disk location"},
	        project_name     => {type => 'String', is_optional => 1, doc => "project name"},
	        assembly_version => {type => 'String', is_optional => 1, doc => "assembly version"},
	        assembly_date    => {type => 'String', is_optional => 1, doc => "assembly date"},
           ],
};

operation Genome::Model::Tools::AssembleReads::Pcap::ParseConfigFile {
    input  => [ 'config_file' ],
    output => [ 'disk_location', 'project_name', 'assembly_version', 'assembly_date'],
};
        
sub execute
{
    my $self = shift;

    my $config_file = $self->config_file;

    my $fh = IO::File->new("<$config_file");

    $self->error_message("Unable to read config file") and return unless $fh;

    my $tmp = {};

    while ( my $line = $fh->getline)
    {
	next if $line =~ /^[\s+$|\#]/;

	chomp $line;

	next unless my ($key, $val) = $line =~ /^(\S+)\s*=\s*(\S+)\s*$/;

	$tmp->{lc $key} = $val;
    }

    return $tmp;
}

1;
