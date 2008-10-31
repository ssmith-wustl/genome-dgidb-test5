#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use GSCApp;

use Test::More;
use Test::MockObject;

plan tests => 8;

our $MAP_FILE_DIR = "/tmp/alignmentfiles.$$/";

END {
    &cleanup();
}

&cleanup();
&setup_files();

my @mock_run_chunks = map {
                my $run_chunk = Test::MockObject->new();
                $run_chunk->set_isa('Genome::RunChunk');
                $run_chunk->set_always('library_name', 'Alexandria');
                $run_chunk->set_always('full_name', 'Foo T. Blarg');
                $run_chunk;
           }
           ( '1', '2' );
    





my @mock_read_sets = map {
                 my $read_set = Test::MockObject->new();
                 $read_set->set_isa('Genome::Model::ReadSet');
                 $read_set->set_always('read_set_id', $_->{'read_set_id'});
                 $read_set->set_always('model_id', $_->{'model_id'});
                 $read_set->set_always('first_build_id', $_->{'first_build_id'});
                 $read_set->set_list('read_set_alignment_files_for_refseq', @{$_->{'files'}});
                 $read_set->set_always('read_set', shift @mock_run_chunks);
                 $read_set;
             }
             ( { read_set_id => 'A', model_id => 12345, first_build_id => undef, files => ["$MAP_FILE_DIR/1", "$MAP_FILE_DIR/2"] },
               { read_set_id => 'B', model_id => 12345, first_build_id => 98765, files => ["$MAP_FILE_DIR/3", "$MAP_FILE_DIR/4"] } );
              

my $model = Test::MockObject->new();
$model->set_isa('Genome::Model');
$model->set_always('genome_model_id', 12345);
$model->set_always('id', 12345);
$model->set_list('read_sets', @mock_read_sets);
$model->set_always('run_chunks', undef);
$model->set_always('read_aligner_name','maq0.6.3');
$UR::Context::all_objects_loaded->{'Genome::Model'}->{12345} = $model;

my $parent_event = Test::MockObject->new();
$parent_event->set_isa('Genome::Model::Event');
$parent_event->set_always('accumulated_alignments_directory','/tmp/blah');
$parent_event->set_always('genome_model_event_id', 8675309);
$parent_event->set_always('id', 8675309);
$UR::Context::all_objects_loaded->{'Genome::Model::Event'}->{8675309} = $parent_event;

GSC::RunLaneSolexa->class;
GSC::RunLaneSolexa->all_objects_are_loaded(1);

my $merge = Genome::Model::Command::Build::ReferenceAlignment::MergeAlignments::Maq->create(
                model => $model,
                ref_seq_id => 1,
                parent_event => $parent_event,
            );
ok($merge, 'Created a Mergealignments::Maq command object');

$merge->queue_status_messages(1);
$merge->dump_status_messages(0);

my $worked = $merge->execute();
ok($worked, 'Execute returned true');

my $maplist = '/tmp/blah/Alexandria_1.maplist';
ok(-f $maplist, 'Expected maplist file');
my $fh = IO::File->new($maplist);
my @lines = $fh->getlines();
$fh->close();
chomp(@lines);

is(scalar(@lines), 4, 'Maplist file had 4 items');
foreach my $num ( 1..4) {
    my $expected = "$MAP_FILE_DIR/$num";
    is(shift @lines, $expected, 'Maplist file contents');
}


sub setup_files {
    mkdir($MAP_FILE_DIR);
    foreach my $name ( '1','2','3','4') {
        IO::File->new("$MAP_FILE_DIR/$name", 'w');
    }
}


sub cleanup {
    rmdir '/tmp/blah';
    unlink "$MAP_FILE_DIR/$_" foreach ( '1','2','3','4');
    rmdir $MAP_FILE_DIR;
}
