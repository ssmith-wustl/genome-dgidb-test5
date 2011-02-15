#!/gsc/bin/perl

use strict;
use warnings;

use Parse::RecDescent qw/RD_ERRORS RD_WARN RD_TRACE/;
use Data::Dumper;
use Test::More tests => 6;
use above 'Genome';

#Parsing tests
my $det_class_base = 'Genome::Model::Tools::DetectVariants2';
my $dispatcher_class = "${det_class_base}::Dispatcher";
use_ok($dispatcher_class);

# hash of strings => expected output hash

my $obj = $dispatcher_class->create(
    snv_detection_strategy => 'samtools r599 [-p 1] intersect samtools r613 [-p 2]',
    indel_detection_strategy => 'samtools r599 [-p 1]',
    sv_detection_strategy => 'breakdancer 2010_06_24 [-p 3]',
    );

my $expected_plan = {
    'breakdancer' => {
        '2010_06_24' => {
            'sv' => [
                {
                    'params' => '-p 3',
                    'version' => '2010_06_24',
                    'name' => 'breakdancer',
                    'filters' => [],
                    'class' => 'Genome::Model::Tools::DetectVariants2::Breakdancer'
                }
            ]
        }
    },
    'samtools' => {
        'r599' => {
            'indel' => [
                {
                    'params' => '-p 1',
                    'version' => 'r599',
                    'name' => 'samtools',
                    'filters' => [],
                    'class' => 'Genome::Model::Tools::DetectVariants2::Samtools'
                }
            ],
            'snv' => [
                {
                    'params' => '-p 1',
                    'version' => 'r599',
                    'name' => 'samtools',
                    'filters' => [],
                    'class' => 'Genome::Model::Tools::DetectVariants2::Samtools'
                }
            ]
        },
        'r613' => {
            'snv' => [
                {
                    'params' => '-p 2',
                    'version' => 'r613',
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

# Test dispatcher for running only samtools for snvs
my $snv_test = $dispatcher_class->create(
    snv_detection_strategy => 'samtools r599',
);
ok($snv_test, "Object to test a simple snv case created");

# Test dispatcher for running only samtools for indels 
my $indel_test = $dispatcher_class->create(
    indel_detection_strategy => 'samtools r599',
);
ok($indel_test, "Object to test a simple indel case created");

# Test dispatcher for running only samtools for snvs with 1 filter
my $snv_filter_test = $dispatcher_class->create(
    snv_detection_strategy => 'samtools r599 filtered by snp-filter v1',
);
ok($snv_filter_test, "Object to test a simple snv case with one filter created");

# Test dispatcher for running a complex case
my $complex_test = $dispatcher_class->create(
    snv_detection_strategy => 'samtools r599 filtered by snp-filter v1 intersect varscan 2.2.4 union samtools r544',
    indel_detection_strategy => 'samtools r599 union samtools r544 intersect samtools r599',
);
ok($complex_test, "Object to test a complex combine case created");

done_testing();
