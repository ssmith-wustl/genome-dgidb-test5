#!/usr/bin/env perl
use strict;
use warnings;
use above "Genome";
use Test::More tests => 13;

my $s = Genome::Sample->get(2824113569);

my $i = Genome::InstrumentData::Imported->create(
    id => -123,
    sample_name             => $s->name,  
    sample_id               => $s->id, 
    import_source_name      => 'Broad',
    original_data_path      => '/tmp/foo',
    import_format           => 'BAM',
    sequencing_platform     => 'solexa',
    description             => 'big ugly bwa file',
    read_count              => 1000,
    base_count              => 100000,
);

ok($i, "created a new imported instrument data");
isa_ok($i,"Genome::InstrumentData::Imported");
is($i->id,-123, "id is set");
is($i->sequencing_platform,'solexa','platform is correct');
is($i->user_name, $ENV{USER}, "user name is correct");
ok($i->import_date, "date is set");

#print Data::Dumper::Dumper($i);

my $i2 = Genome::InstrumentData::Imported->create(
    id => -456,
    sample_name             => $s->name,  
    sample_id               => $s->id, 
    import_source_name      => 'Broad',
    original_data_path      => '/tmp/nst',
    import_format           => 'BAM',
    sequencing_platform     => '454',
    description             => 'big ugly bwa file',
    read_count              => 1000,
    base_count              => 100000,
);

ok($i2, "created a new imported instrument data");
isa_ok($i2,"Genome::InstrumentData::Imported");
is($i2->id, -456, "id is set");
is($i2->sequencing_platform,'454','platform is correct');
is($i2->user_name, $ENV{USER}, "user name is correct");
ok($i2->import_date, "date is set");

my $ok;
eval { $ok = UR::Context->_sync_databases(); };
ok($ok, "saves to the database!");

#UR::Context->commit;
#call $instrument_data->delete to delete

