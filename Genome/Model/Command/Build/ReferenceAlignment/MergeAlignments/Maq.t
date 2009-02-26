#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use GSCApp;

use Test::More;
use Test::MockObject;

plan tests => 9;

our $MAP_FILE_DIR = "/tmp/alignmentfiles.$$/";

END {
    &cleanup();
}

&cleanup();
&setup_files();

my @mock_instrument_data_assignments = map {
    my $ida = Genome::Model::InstrumentDataAssignment->create_mock(
                                                                   id => $_->{'instrument_data_id'} .' '. $_->{'model_id'},
                                                                   instrument_data_id => $_->{'instrument_data_id'},
                                                                   model_id => $_->{'model_id'},
                                                                   first_build_id => $_->{'first_build_id'},
                                                                   library_name => 'Alexandria',
                                                                   full_name => 'Foo T. Blarg',
                                                               );
    $ida->set_list('alignment_files_for_refseq', @{$_->{'files'}});
}
    ( { instrument_data_id => '-1',
        model_id => 12345,
        first_build_id => undef,
        files => ["$MAP_FILE_DIR/1", "$MAP_FILE_DIR/2"] },
      { instrument_data_id => '-2',
        model_id => 12345,
        first_build_id => 98765,
        files => ["$MAP_FILE_DIR/3", "$MAP_FILE_DIR/4"] } );

my $pp = Genome::ProcessingProfile->create_mock(id => 12344);
my $model = Genome::Model->create_mock(
                                       id => 12345,
                                       genome_model_id => 12345,
                                       name => 'test_model_name',
                                       subject_name => 'test_subject_name',
                                       subject_type => 'test_subject_type',
                                       processing_profile_id => $pp->id,
                                   );
$model->set_list('instrument_data_assignments', @mock_instrument_data_assignments);
$model->set_always('read_aligner_name','maq0_6_3');

my $build = Genome::Model::Build->create_mock(
                                              id => 8675309,
                                              build_id => 8675309,
                                              model_id => 12345,
                                          );
$build->set_always('accumulated_alignments_directory','/tmp/blah');

GSC::RunLaneSolexa->class;
GSC::RunLaneSolexa->all_objects_are_loaded(1);

my $merge = Genome::Model::Command::Build::ReferenceAlignment::MergeAlignments::Maq->create(
                model => $model,
                ref_seq_id => 1,
                build => $build,
            );
ok($merge, 'Created a Mergealignments::Maq command object');
ok($merge->bsub_rusage(), 'inherits bsub_rusage method');

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
