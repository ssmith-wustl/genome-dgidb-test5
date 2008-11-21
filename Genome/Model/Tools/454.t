#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Test::More tests => 5;

BEGIN {
        use_ok('Genome::Model::Tools::454');
}

my $arch_os = `uname -m`;
chomp($arch_os);

my $installed_path = '';
#my $test_installed_path = '';


if ($arch_os =~ /64/) {
    $installed_path = '/gsc/pkg/bio/454/installed-64/bin';
} else {
    $installed_path = '/gsc/pkg/bio/454/installed/bin';
}

my $tool_454 = Genome::Model::Tools::454->create();
isa_ok($tool_454,'Genome::Model::Tools::454');
is($tool_454->arch_os,$arch_os,'arch_os');
ok(-d $tool_454->bin_path,'bin directory exists');
is($tool_454->bin_path,$installed_path,'expected path found');


exit;
