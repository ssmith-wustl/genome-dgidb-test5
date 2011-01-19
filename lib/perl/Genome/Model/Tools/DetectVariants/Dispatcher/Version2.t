#!/gsc/bin/perl

use strict;
use warnings;

use Parse::RecDescent qw/RD_ERRORS RD_WARN RD_TRACE/;
use Data::Dumper;
use Test::More tests => 14;
#use Test::More skip_all => 'test in development';
use above 'Genome';

#Use this check if tests are added to actually run detectors
#my $archos = `uname -a`;
#if ($archos !~ /64/) {
#    plan skip_all => "Must run from 64-bit machine";
#} else {
#    plan tests => 5;
#}

#Parsing tests
my $dispatcher = 'Genome::Model::Tools::DetectVariants::Dispatcher::Version2';

# hash of strings => expected output hash
my %expected = (
    "samtools v1 {}" => {
        detector => {
            name => "samtools",
            version => "v1",
            params => {},
            filters => undef,
        }
    },

    "var-scan v2 {foo => 'bar'} && samtools v1 {p => 1} filtered by thing v1 {}" => {
        intersect => [
            {
                detector => {
                    name => "var-scan",
                    version => "v2",
                    params => { foo => 'bar'},
                    filters => undef,
                },
            },
            {
                detector => {
                    name => "samtools",
                    version => "v1",
                    params => { p => 1},
                    filters => [{name => 'thing', version => 'v1', params => {}}],
                }
            },
        ]
    },

    "a v1 {b => 1} filtered by c v2 {}, d v3 { f=> 1 } || (a v1 {} && b v2 {})" => {
        union => [
            {
                detector => {
                    name => "a",
                    version => "v1",
                    params => { b => 1},
                    filters => [
                        {name => 'c', version => 'v2', params => {}},
                        {name => 'd', version => 'v3', params => { f => 1}},
                     ],
                },
            },
            {
                intersect => [
                    {
                        detector => {
                            name => "a",
                            version => "v1",
                            params => {},
                            filters => undef,
                        },
                    },
                    {
                        detector => {
                            name => "b",
                            version => "v2",
                            params => {},
                            filters => undef,
                        },
                    },
                ],
            },
        ],
    }
);

my @expected_failures = (
    "badness", # missing version, params
    "badness v1", # missing params
    "badness v1 {} filtered by", # missing filter
    "badness v1 {} filtered by foo", # missing filter version
    "badness v1 {} filtered by foo v1", # missing filter params
    "badness v1 {} filtered by foo v1 {} &&", # missing detector after &&
    "(badness v1 {} filtered by foo v1 {}", # missing )
    "badness v1 {} filtered by foo v1 {})", # extra )
);
    

for my $str (keys %expected) {
    my $tree = $dispatcher->parse_detector_strategy($str);
    ok($tree, 'able to parse detector string')
        or die "failed to parse $str";
    is_deeply($tree, $expected{$str}, 'tree looks as expected') 
        or die "incorectly parsed $str: expected: " . Dumper($expected{$str}) . "got: " . Dumper($tree);
}

# don't want to see all the yelling while testing failures.
$::RD_ERRORS = undef;
$::RD_WARN = undef;
$::RD_TRACE = undef;
for my $str (@expected_failures) {
    my $tree = undef;
    print " -- $str\n";
    eval {
        $tree = $dispatcher->parse_detector_strategy($str);
    };
    ok(!$tree, 'bad input fails to parse as expected')
        or die "did not fail to parse bad string: $str";
}
