#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 2;

use above "Genome";

=cut
=cut

    my $build_id = 93293206;
    my $build = Genome::Model::Build->get(build_id => $build_id);
    ok($build, "got a build");

    my ($id, $name) = ($build_id,'RefSeqMaq');
    my $report = Genome::Model::Report->create(build_id=>$id, name=>$name);
   ok($report, "got a report"); 
