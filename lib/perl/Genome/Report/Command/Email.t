#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

use_ok('Genome::Report::Command::Email') or die;

my $dir = '/gsc/var/cache/testsuite/data/Genome-Report-XSLT';
my $cmd = Genome::Report::Command::Email->create(
    report_directory => $dir.'/Assembly_Stats',
    xsl_files => $dir.'/AssemblyStats.txt.xsl',
    to => Genome::Config->user_email,
);
ok($cmd, 'create email command');

$cmd->dump_status_messages(1);

no warnings;
# overload 'Close' to not send the mail, but to cancel it 
*Mail::Sender::Close = sub{ my $sender = shift; $sender->Cancel; return 1; };
use warnings;

ok($cmd->execute, 'execute');

done_testing();
exit;

