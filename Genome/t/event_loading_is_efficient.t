#!/gsc/bin/perl

#$ENV{UR_DBI_MONITOR_SQL}=1;
use above "Genome";
use Test::More tests => 6;
use Genome::Model::Command::AddReads;

my $query_count;
Genome::DataSource::GMSchema->create_subscription(method => 'query',
                                                  callback => sub { $query_count++ },
                                                 );

my $load_count;
Genome::Model::Event->create_subscription(method => 'load',
                                          callback => sub { $load_count++},
                                      );

my @events = Genome::Model::Command::AddReads->get(model_id => '2509644372');
is(scalar(@events), 0 , "Genome::Model::Command::AddReads->get() correctly returns 0 items for model_id '2509644372'");
is($query_count, 2, "get() generated 2 queries, one for the main class, and one for one subclass with a table (build)");
ok($load_count, "at least one object was loaded by the get()");

$query_count = 0;
$load_count = 0;
@events = Genome::Model::Command::Build::ReferenceAlignment::FindVariations->get(model_id => '2509644372', event_status => 'Succeeded');
ok(scalar(@events), "Genome::Model::Command::Build::ReferenceAlignment::FindVariations->get() returned at least one event");
is($query_count, 0, "get() generated no queries");
is($load_count, 0, "and correctly loaded no objects");

exit;
