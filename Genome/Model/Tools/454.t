#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

BEGIN {
    my $archos = `uname -a`;
    if ($archos !~ /64/) {
        plan skip_all => "Must run from 64-bit machine";
    }
    plan tests => 6;
    use_ok('Genome::Model::Tools::454');
}

my $arch_os = `uname -m`;
chomp($arch_os);

my $installed_link = '/gsc/pkg/bio/454/installed';
my $installed_path = readlink($installed_link);

my $tool_454 = Genome::Model::Tools::454->create();
isa_ok($tool_454,'Genome::Model::Tools::454');

my $installed_bin = $tool_454->resolve_454_path . $installed_path .'/bin';

is($tool_454->arch_os,$arch_os,'arch_os');
like($tool_454->version,'/\d\.\d.\d{2}.\d{2}/','found a version like 0.0.00.00');
ok(-d $tool_454->bin_path,'bin directory exists');
is($tool_454->bin_path,$installed_bin,'expected path found for bin directory');

exit;
