#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';
use Test::More;

sudo_user_is_detected();

done_testing();

sub sudo_user_is_detected {
    my $username = 'thomas';
    my $body_text = 'This is a test message.';

    local $ENV{SUDO_USER} = $username;
    is($ENV{SUDO_USER}, $username, 'set SUDO_USER to ' . $username);

    my $subject = UR::Value->get('subject');
    isa_ok($subject, 'UR::Value', 'subject');

    my $note = Genome::MiscNote->create(
        subject => $subject,
        header_text => 'Test Note',
        body_text => $body_text,
    );
    isa_ok($note, 'Genome::MiscNote', 'note');

    like($note->body_text, qr/^$username\ is\ running\ as/, 'note prepended with sudo_username');
}

