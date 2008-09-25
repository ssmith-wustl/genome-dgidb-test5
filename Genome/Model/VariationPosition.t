use above Genome;
#use Test::More tests => 17;
use Test::More skip_all => 'pending charris refactor of the solexa pipeline';


# This is the AML-nature_34skin-v0b model
my @s = Genome::Model::VariationPosition->get(model_id => 2667602813,
                                              ref_seq_id => 2,
                                              position => { operator => '<', value => '10000' },
                                              metric_snp_quality => { operator => '>', value => 2 },
                                            );

# There should be at least 2 snps, right?
ok(@s >= 2, 'Got at least 2 snps for model');

# Test some of the properties of the firs snp found
is($s[0]->model_id, 2667602813, 'model id is correct');
is($s[0]->ref_seq_id, 2, 'ref_seq_id is correct');
ok($s[0]->position, 'object has a position');
ok($s[0]->position > 0, 'position is greater than 0');
ok($s[0]->position < 10000, 'position is less than 10000');

ok($s[0]->reference_base, 'object has a reference_base');
ok($s[0]->consensus_base, 'object has a consensus_base');
ok($s[0]->consensus_quality, 'object has a consensus_quality');
ok($s[0]->read_depth, 'object has a read_depth');
ok($s[0]->avg_num_hits, 'object has a avg_num_hits');
ok($s[0]->max_mapping_quality, 'object has a max_mapping_quality');
ok($s[0]->min_conensus_quality, 'object has a min_conensus_quality');

ok($s[0]->metric_snp_quality > 2, 'indirect property metric_snp_quality is correctly greater than 2');

my $metric = $s[0]->experimental_metric;
is($s[0]->model_id, $metric->model_id, "model_id match between VariationPosition and its ExperimentalMetric");
is($s[0]->ref_seq_id, $metric->chromosome, "ref_seq_id match between VariationPosition and its ExperimentalMetric");
is($s[0]->position, $metric->position, "position match between VariationPosition and its ExperimentalMetric");
                        
