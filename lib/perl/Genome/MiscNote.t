#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';
use Test::More;

sudo_username_is_detected();
sudo_username_isnt_detected();

done_testing();

sub miscnote_body_text {
    my $sudo_username = shift;
    my $body_text = shift;

    no warnings qw(redefine);
    *Genome::Sys::sudo_username = sub { return $sudo_username };
    use warnings qw(redefine);

    my $subject = UR::Value->get('subject');
    isa_ok($subject, 'UR::Value', 'subject');

    my $note = Genome::MiscNote->create(
        subject => $subject,
        header_text => 'Test Note',
        body_text => $body_text,
    );
    isa_ok($note, 'Genome::MiscNote', 'note');

    return $note->body_text;
}

sub sudo_username_isnt_detected {
    my $message = 'Sample note message.';
    my $body_text = miscnote_body_text('', $message);
    is($body_text, $message, 'note didnt prepend sudo_username');
}

sub sudo_username_is_detected {
    my $message = 'Sample note message.';
    my $sudo_username = 'sample-sudo-username';
    my $body_text = miscnote_body_text($sudo_username, $message);
    is($body_text, $sudo_username . ' is running as ' . Genome::Sys->username . ". $message", 'note prepended with sudo_username');
}
