use strict;
use warnings;

use Workflow;

use Test::More tests => 27;

use File::Temp qw(tempdir);


BEGIN {
    use_ok('Genome::Model::Tools::Pcap::Run::CreateDirectories');
}

my $disk_location    = tempdir(CLEANUP => 1);
my $project_name     = 'TEST0001A';
my $assembly_version = 1;
my $assembly_date    = '20080731';

my $path = $disk_location.'/'.$project_name.'-'.$assembly_version.'_'.$assembly_date.'.pcap';

my $command = Genome::Model::Tools::Pcap::Run::CreateDirectories->create(
                                                                                   disk_location    => $disk_location,
                                                                                   project_name     => $project_name,
                                                                                   assembly_version => $assembly_version,
                                                                                   assembly_date    => $assembly_date,
                                                                                  );

isa_ok($command, 'Genome::Model::Tools::Pcap::Run::CreateDirectories');

is($command->disk_location(),    $disk_location,    'disk location');
is($command->project_name(),     $project_name,     'project name');
is($command->assembly_version(), $assembly_version, 'assembly version');
is($command->assembly_date(),    $assembly_date,    'assembly_date');

ok($command->execute(), 'execute');

ok(-e $path, 'path exists');
ok(-d $path, 'path is a directory');

foreach my $sub_dir (
                     qw(
                        edit_dir input output phd_dir chromat_dir 
                        blastdb acefiles ftp read_dump
                       ) 
                    ) {
                    
    ok(-e "$path/$sub_dir", "$sub_dir exists");
    ok(-d "$path/$sub_dir", "$sub_dir is a directory");

}
