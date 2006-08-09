#! perl
# test script for GSCApp::Mail
use warnings;
use strict;
use Test::More tests => 24;
BEGIN { use_ok('GSCApp::Mail'); }

# check config
ok(App::Mail->config(mqueue => "."), 'set mqueue directory');
my $ext = App::Mail->config('ext');
ok($ext, 'got mail extension');
$ext .= "-$$";
ok(App::Mail->config(ext => $ext), 'set mail extension');

# send mail when no mail is present
ok(App::Mail->smail == 0, 'sent no mail');

# create standard mail
my $email = getlogin || getpwuid($<) || 'nobody';
ok
(
    App::Mail->mail
    (
        From => qq("GSCApp::Mail Test" <$email\@watson.wustl.edu>),
        To => $email,
        Subject => 'GSCApp::Mail test',
        Message => "First test message from GSCApp::Mail test.\n"
    ),
   'created mail file'
);
my @mh = glob("*$ext");
is(@mh, 1, 'mail file created');
# send the mail
is(App::Mail->smail, 1, 'sent one mail');

# send a mail with no From
ok
(
    App::Mail->mail
    (
        To => $email,
        Subject => 'GSCApp::Mail test 2',
        Message => "Second test message from GSCApp::Mail test.\n"
    ),
    'automatic From creation'
);
@mh = glob("*$ext");
is(@mh, 1, 'mail file created');
# send a mail without setting the From
ok
(
    App::Mail->mail
    (
        To => $email,
        From => '',
        Subject => 'GSCApp::Mail test 3',
        Message => "Third test message from GSCApp::Mail test.\n"
    ),
    'automatic From set'
);
@mh = glob("*$ext");
is(@mh, 2, 'mail files created');
# send the mail
is(App::Mail->smail, 2, 'sent mails');

# test failures
App::MsgLogger->message_callback('error',   sub { return 1});
ok(!App::Mail->mail(Subject => 's', Message => 'headers missing'),
   'rejected message with no To');
ok(!App::Mail->mail(To => 'nobody', Message => 'headers missing'),
   'rejected message with no Subject');
ok(!App::Mail->mail(To => 'nobody', Subject => 's'),
   'rejected message with no Message');
ok(!App::Mail->mail(To => '', Subject => 's', Message => 'headers not set'),
   'rejected message with To unset');
ok(!App::Mail->mail(To => 'nobody', Subject => '', Message => 'headers not set'),
   'rejected message with Subject unset');
ok(!App::Mail->mail(To => 'nobody', Subject => 's', Message => ''),
   'rejected message with Message unset');
ok(!App::Mail->mail(From => '<nobody>', To => 'nobody', Subject => 's', Message => 'bad address'), 'rejected message with complicated unqualified From address');
ok(!App::Mail->mail(To => '"No One" <nobody>', Subject => 's', Message => 'bad address'), 'rejected message with complicated unqualified To address');
ok(!App::Mail->mail(To => 'nobody', Cc => 'No One <nobody>', Subject => 's', Message => 'bad address'), 'rejected message with complicated unqualified Cc address');
ok(!App::Mail->mail(To => 'nobody', Bcc => 'nobody (No One)', Subject => 's', Message => 'bad address'), 'rejected message with complicated unqualified Bcc address');
ok(!App::Mail->mail(To => '@cnn.com', Subject => 's', Message => 'bad address'), 'rejected message with domain only address');
exit(0);

# $Header$
