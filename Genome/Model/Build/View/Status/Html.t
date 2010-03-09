#!/usr/bin/env perl
use strict;
use warnings;

use above "Genome";
use Genome::Model::Build::View::Status::Html; 

use Test::More tests => 4;

# TODO: use one of the test builds
my $subject = Genome::Model::Build->get(101289765);
ok($subject, "found expected build subject") or die "test cannot continue...";

my $view_obj = Genome::Model::Build::View::Status::Html->create(subject_id => 101289765, use_lsf_file => 1); 
ok($view_obj, "created a view") or die "test cannot continue...";

my $xml = $view_obj->_generate_content();
ok($xml, "view returns HTML") or die "test cannot continue...";

my @diff =
    grep { $_ !~ /generated-at/ }
    grep { /\w/ }
    Genome::Utility::FileSystem->diff_file_vs_text(__FILE__ . '.expected',$xml);

is("@diff","","HTML has no differences from expected value");

