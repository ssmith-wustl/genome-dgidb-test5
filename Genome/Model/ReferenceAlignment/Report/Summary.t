#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 8;
use FindBin qw/$Bin/;
use Genome::Utility::FileSystem;
 
my $tmp = Genome::Utility::FileSystem->create_temp_directory();

sub rmtree {
    system "/bin/rm -r $tmp";
    if (-e $tmp) {
        die "failed to remove directory $tmp: $!";
    }
}

die "temp in odd location! $tmp" unless $tmp =~ /\/tmp/;

if (-e $tmp) {
    warn "removing previously left-behind directory $tmp...";
    rmtree();
}

mkdir($tmp) or die "Failed to create directory $tmp: $!";

my $build_id = "96267575";
my $build = Genome::Model::Build->get($build_id);
ok($build, "build found with id $build_id");

my $r = Genome::Model::ReferenceAlignment::Report::Summary->create(
    build_id => $build_id,
    #report_template => '/gscuser/jpeck/svn/pm2/Genome/Model/ReferenceAlignment/Report/build_report_template_html.tt2',
    #report_template => '/gscuser/jpeck/svn/pm2/Genome/Model/ReferenceAlignment/Report/build_report_template_txt.tt2',
);
ok($r, "created a new report");

my @t = $r->report_templates;
is(scalar(@t),2, "got 2 templates") or diag(@t);

my $v = $r->generate_report;
ok($v, "generation worked");

my $result = $v->save($tmp);
ok($result, "saved to $tmp");

my $name = $r->name;
$name =~ s/ /_/g;

ok(-d "$tmp/$name", "report directory $tmp/$name is present");
ok(-e "$tmp/$name/report.txt", 'text report is present');
ok(-e "$tmp/$name/report.html", 'html report is present');

rmtree();


