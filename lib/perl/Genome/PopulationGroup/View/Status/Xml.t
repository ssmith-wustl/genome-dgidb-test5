#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome"; 

use Test::More tests => 6;

use_ok('Genome::PopulationGroup::View::Status::Xml') or die "test cannot continue...";

#2849242320 is Mock_V1_Baylor_PooledDNA
my $subject = Genome::PopulationGroup->get(2849242320);
ok($subject, "found expected population-group subject") or die "test cannot continue...";

my $view_obj = $subject->create_view(perspective => 'status', toolkit => 'xml'); 
ok($view_obj, "created a view") or die "test cannot continue...";
isa_ok($view_obj, 'Genome::PopulationGroup::View::Status::Xml');

my $xml = $view_obj->_generate_content();
ok($xml, "view returns XML") or die "test cannot continue...";

SKIP: {
    skip "No Xml.t.expected in place.",1;
    my @diff =
        grep { $_ !~ /generated-at/ }
        grep { /\w/ }
        Genome::Sys->diff_file_vs_text(__FILE__ . '.expected',$xml);
    
    is("@diff","","XML has no differences from expected value");
}