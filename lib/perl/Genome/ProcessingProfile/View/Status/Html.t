#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Test::More tests => 6;

use_ok('Genome::ProcessingProfile::View::Status::Html') or die "test cannot continue...";

#2282116 is bwa0.5.5 and samtools r453 and picard r1.17 and trimq2_smart1
my $subject = Genome::ProcessingProfile->get(2282116);
ok($subject, "found expected processing-profile subject") or die "test cannot continue...";

my $view_obj = $subject->create_view(
    xsl_root => Genome->base_dir . '/xsl',
    rest_variable => '/cgi-bin/rest.cgi',
    toolkit => 'html',
    perspective => 'status',
); 
ok($view_obj, "created a view") or die "test cannot continue...";
isa_ok($view_obj, 'Genome::ProcessingProfile::View::Status::Html');

my $html = $view_obj->_generate_content();
ok($html, "view returns HTML") or die "test cannot continue...";

SKIP: {
    skip "No Html.t.expected in place.",1;
    my @diff =
        grep { $_ !~ /generated-at/ }
        grep { /\w/ }
        Genome::Utility::FileSystem->diff_file_vs_text(__FILE__ . '.expected',$html);
    
    is("@diff","","HTML has no differences from expected value");
}
