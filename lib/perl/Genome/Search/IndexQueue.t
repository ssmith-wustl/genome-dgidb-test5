#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use above "Genome";
use_ok('Genome::Search::IndexQueue') || die;

require Genome::Search;
my $orig_is_indexable = \&Genome::Search::is_indexable;
my $text_is_indexable = sub {
    my ($class, $object) = @_;
    if ($object->isa('UR::Value::Text')) {
        return 1;
    }
    else { 
        return;
    }
};

test_create_or_update_missing_subject();
test_create_or_update_missing_action();
test_create_or_update_missing_timestamp();
test_create_or_update_existing_subject();
test_create_or_update_non_indexable_subject();

done_testing();

sub test_create_or_update_missing_subject {
    my $tx = UR::Context::Transaction->begin();

    my $index_queue = eval {
        Genome::Search::IndexQueue->create_or_update(
            action => 'add',
        );
    };
    my $error = $@;

    is($index_queue, undef, 'failed to create_or_update index_queue when missing subject');
    like($error, qr/subject/, 'error mentions subject');

    $tx->rollback();
}

sub test_create_or_update_missing_action {
    my $tx = UR::Context::Transaction->begin();

    my $subject = UR::Value::Text->get('Hello, world.');
    my $index_queue = eval {
        Genome::Search::IndexQueue->create_or_update(
            subject => $subject,
        );
    };
    my $error = $@;

    is($index_queue, undef, 'failed to create_or_update index_queue when missing action');
    like($error, qr/action/, 'error mentions action');

    $tx->rollback();
}

sub test_create_or_update_missing_timestamp {
    my $tx = UR::Context::Transaction->begin();

    *Genome::Search::is_indexable = $text_is_indexable;

    my $subject = UR::Value::Text->get('Hello, world.');
    my $index_queue = Genome::Search::IndexQueue->create_or_update(
        subject => $subject,
        action => 'add',
    );

    isa_ok($index_queue, 'UR::Object', 'create_or_update returned an object');
    ok($index_queue->timestamp, 'timestamp was added');

    *Genome::Search::is_indexable = $orig_is_indexable;

    $tx->rollback();
}

sub test_create_or_update_existing_subject {
    my $tx = UR::Context::Transaction->begin();

    *Genome::Search::is_indexable = $text_is_indexable;

    my $subject = UR::Value::Text->get('Hello, world.');
    my $index_queue = Genome::Search::IndexQueue->create_or_update(
        subject => $subject,
        action => 'add',
    );

    isa_ok($index_queue, 'UR::Object', 'create_or_update returned an object');
    is($index_queue->action, 'add', 'action is set to add');

    my $index_queue_2 = Genome::Search::IndexQueue->create_or_update(
        subject => $subject,
        action => 'delete',
    );
    isa_ok($index_queue_2, 'UR::Object', 'create_or_update returned an object');

    is($index_queue_2, $index_queue, 'new index_queue is same as old since they have same "ID"');
    is($index_queue->action, 'delete', 'action is set to delete');

    *Genome::Search::is_indexable = $orig_is_indexable;

    $tx->rollback();
}

sub test_create_or_update_non_indexable_subject {
    my $tx = UR::Context::Transaction->begin();

    my $subject = UR::Value::Text->get('Hello, world.');
    my $index_queue = eval {
        Genome::Search::IndexQueue->create_or_update(
            subject => $subject,
            action => 'add',
        );
    };
    my $error = $@;

    is($index_queue, undef, 'failed to create_or_update index_queue when subject is not indexable');
    like($error, qr/indexable/, 'error mentions indexable');

    $tx->rollback();
}
