use Test::More skip_all => "under development";

use above 'Genome';

#my $the_model_id = 2733662090;#2661729970;
#my $the_ref_seq_id = 123456789;
#my $the_ref_seq_name = 22;
# RefSeq objects aren't in the database yet
#Genome::Model::RefSeq->create(model_id => $the_model_id, ref_seq_id => $the_ref_seq_id, ref_seq_name => $the_ref_seq_name);

# There should be at least one VariationPosition with a red depth of 2, right?
#$i = Genome::Model::RefSeq->create_iterator(where => [ model_id=> $the_model_id,
#                                                       ref_seq_name => $the_ref_seq_name,
#                                                       variation_position_read_depths => 2 ]);
#ok($i, 'created an iterator for Genome::Model::RefSeq objects');

#my @o;
#while ($o = $i->next) {
#    ok($o, 'iterator returned an object');
#    push @o, $o;

#}

#is(scalar(@o), 1, 'Iterator returned only one object');
#my $o = $o[0];
#is($o->model_id, $the_model_id, "Returned RefSeq's model_id is correct");
#is($o->ref_seq_name, $the_ref_seq_name, "Returned RefSeq's ref_seq_name is correct");
