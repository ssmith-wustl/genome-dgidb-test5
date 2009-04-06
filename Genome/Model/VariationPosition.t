use above Genome;
#use Test::More tests => 19;
use Test::More skip_all => 'This model leans heavily on metric_snp_quality, which uses experimental metrics, which live in the other_snp_related_metrics folder, which is no longer produced!  If you know what any of this means, fix it!';


# This is the AML-nature_34skin-v0b model
my $the_model_id = 2771359026;  #jpecks test-pipeline-model
my $the_ref_seq_name = 2;
my $the_ref_seq_bridge = Genome::Model::RefSeq->get(ref_seq_name => $the_ref_seq_name, model_id => $the_model_id);
my $the_ref_seq_id = $the_ref_seq_bridge->ref_seq_id;
my @s = Genome::Model::VariationPosition->get(model_id => $the_model_id,
                                              ref_seq_id => $the_ref_seq_id,
                                              position => { operator => '<', value => '10000' },
                                              metric_snp_quality => { operator => '>', value => 2 },
                                            );

die;
# There should be at least 2 snps, right?
ok(@s >= 2, 'Got at least 2 snps for model');

# Test some of the properties of the firs snp found
is($s[0]->model_id, $the_model_id, 'model id is correct');
is($s[0]->ref_seq_name, $the_ref_seq_name, 'ref_seq_name is correct');
ok(defined($s[0]->position), 'object has a position');
ok($s[0]->position > 0, 'position is greater than 0');
ok($s[0]->position < 10000, 'position is less than 10000');

ok(defined($s[0]->reference_base), 'object has a reference_base');
ok(defined($s[0]->consensus_base), 'object has a consensus_base');
ok(defined($s[0]->consensus_quality), 'object has a consensus_quality');
ok(defined($s[0]->read_depth), 'object has a read_depth');
ok(defined($s[0]->avg_num_hits), 'object has a avg_num_hits');
ok(defined($s[0]->max_mapping_quality), 'object has a max_mapping_quality');
ok(defined($s[0]->min_conensus_quality), 'object has a min_conensus_quality');

ok($s[0]->metric_snp_quality > 2, 'indirect property metric_snp_quality is correctly greater than 2');

my $metric = $s[0]->experimental_metric;
is($s[0]->model_id, $metric->model_id, "model_id match between VariationPosition and its ExperimentalMetric");
is($s[0]->ref_seq_name, $metric->chromosome, "ref_seq_name match between VariationPosition and its ExperimentalMetric");
is($s[0]->position, $metric->position, "position match between VariationPosition and its ExperimentalMetric");
                        

my $model_refseq = Genome::Model::RefSeq->get(model_id => $the_model_id,
                                              ref_seq_name => $the_ref_seq_name);
ok($model_refseq, "Got a Genome::Model::RefSeq");
my @vps = $model_refseq->variation_positions(position => { operator => '<', value => 100000 });
ok(scalar(@vps), 'Got at least one VariationPosition for that RefSeq (through reverse_id_by indirect property)');
