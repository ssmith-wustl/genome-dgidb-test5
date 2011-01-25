#!/gsc/bin/perl

use strict;
use warnings;

use Parse::RecDescent qw/RD_ERRORS RD_WARN RD_TRACE/;
use Data::Dumper;
use Test::More tests => 2;
#use Test::More skip_all => 'test in development';
use above 'Genome';

#Parsing tests
my $det_class_base = 'Genome::Model::Tools::DetectVariants2';
my $dispatcher_class = "${det_class_base}::Dispatcher";
use_ok($dispatcher_class);

# hash of strings => expected output hash

my $obj = $dispatcher_class->create(
    snv_detection_strategy => 'samtools v1 [-p 1] && samtools v2 [-p 2]',
    indel_detection_strategy => 'samtools v1 [-p 1]',
    sv_detection_strategy => 'breakdancer v1 [-p 3]',
    );

my $expected_plan = {
    'breakdancer' => {
        'v1' => {
            'sv' => [
                {
                    'params' => '-p 3',
                    'version' => 'v1',
                    'name' => 'breakdancer',
                    'filters' => [],
                    'class' => 'Genome::Model::Tools::DetectVariants2::Breakdancer'
                }
            ]
        }
    },
    'samtools' => {
        'v1' => {
            'indel' => [
                {
                    'params' => '-p 3',
                    'version' => 'v1',
                    'name' => 'samtools',
                    'filters' => [],
                    'class' => 'Genome::Model::Tools::DetectVariants2::Samtools'
                }
            ],
            'snv' => [
                {
                    'params' => '-p 1',
                    'version' => 'v1',
                    'name' => 'samtools',
                    'filters' => [],
                    'class' => 'Genome::Model::Tools::DetectVariants2::Samtools'
                }
            ]
        },
        'v2' => {
            'snv' => [
                {
                    'params' => '-p 2',
                    'version' => 'v2',
                    'name' => 'samtools',
                    'filters' => [],
                    'class' => 'Genome::Model::Tools::DetectVariants2::Samtools',
                }
            ]
        }
    }
};

my ($trees, $plan) = $obj->plan;
is_deeply($plan, $expected_plan, "plan matches expectations");

done_testing();
