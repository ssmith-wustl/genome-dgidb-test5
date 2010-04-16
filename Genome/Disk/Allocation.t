#!/gsc/bin/perl

use strict;
use warnings;

use Test::More tests => 12;

use above 'Genome';

BEGIN {
        use_ok('Genome::Disk::Allocation');
};
my @allocations = Genome::Disk::Allocation->get();
ok(scalar(@allocations),'got allocations');


## monitor_allocate_command tests
my $send_message_called;
{
    no warnings;
    *Genome::Config::admin_notice_users = sub { return (scalar getpwuid($<)) };
    my $sm = \&Genome::Disk::Allocation::send_message_about_command;
    *Genome::Disk::Allocation::send_message_about_command = sub {
        if (defined $send_message_called) {
            $send_message_called = [$send_message_called,$_[4]];
        } else {
            $send_message_called = $_[4];
        }
        $sm->(@_);
    };
}

$Genome::Disk::Allocation::after_start = 6;
$Genome::Disk::Allocation::after_lock_acquired = 2;

ok(Genome::Disk::Allocation->monitor_allocate_command('sleep 5'),
    'monitor short period of time' 
);

ok(!defined $send_message_called,'send message was not called');

ok(Genome::Disk::Allocation->monitor_allocate_command('sleep 7'),
    'monitor 7 seconds'
);

is($send_message_called,0,'send message was called by after_start');
undef $send_message_called;

ok(Genome::Disk::Allocation->monitor_allocate_command(
    'echo "genome allocate: STATUS: Lock acquired" >&2; sleep 3'),
    'monitor 3 seconds with echo'
);

is($send_message_called,1,'send message was called by after_lock_acq');
undef $send_message_called;

## run long enough so after_start causes a fail, then print lock acquired
## and run longer than after_lock_acquired

ok(Genome::Disk::Allocation->monitor_allocate_command('sleep 8; echo "genome allocate: STATUS: Lock acquired" >&2; sleep 3'),
    'monitor 3 seconds with echo'
);

ok(ref($send_message_called) eq 'ARRAY','got multiple messages');

is($send_message_called->[0],0,'send message was called by after_start');
is($send_message_called->[1],1,'send message was called by after_lock_acq');
undef $send_message_called;


exit;
