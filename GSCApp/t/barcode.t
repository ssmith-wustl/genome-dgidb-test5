#! perl
# test script for GSCApp::Print::Barcode
use lib '..';
use warnings;
use strict;
use Test::More skip_all => "BROKEN ON CRON SERVER"; # tests => 16;
use IO::File;
use File::Path;
BEGIN { use_ok('GSCApp::Print::Barcode'); }

# create local spool
my $printer = 'test';
mkpath("var/spool/bpd/$printer");

# print good barcodes
ok
(
    App::Print::barcode->print
    (
        printer => 'test',
        protocol => 'barcode',
        type => 'barcode',
        data => [ [ 123456, 'test label', 'second label' ] ]
    ),
    'print simple barcode'
);
ok
(
    App::Print::barcode->print
    (
        printer => 'test',
        protocol => 'barcode',
        type => 'label',
        data => [ '1234567890123456789012345678901234' ]
    ),
    'print label'
);

# test arrays
ok
(
    App::Print::barcode->print
    (
        printer => 'test',
        protocol => 'barcode',
        type => 'barcode',
        data =>
        [
            [ 123456, 'first barcode label', 'second barcode label' ],
            [ 'abcdef', 'how about another', 'barcode label' ]
        ]
    ),
    'print barcode array'
);
ok
(
    App::Print::barcode->print
    (
        printer => 'test',
        protocol => 'barcode',
        type => 'label',
        data =>
        [
            'first label label',
            'second label label',
            'last label label'
        ]
    ),
    'print label array'
);

# get printer name
my @ps = GSCApp::Print::Barcode->printers;
ok(@ps, 'got printers');
ok(@ps == 1, 'only got one printer');
ok($ps[0] eq $printer, "printer is $printer");
my @gaps = GSCApp::Print::Barcode->get_available_printer;
is_deeply(\@gaps, \@ps, 'get_available_printer compat');

# catch bad ones
App::MsgLogger->message_callback('error', sub { my $m = $_[0]->text; print STDERR "$m\n" unless $m =~ m/barcode is invalid/; return 1; });
App::MsgLogger->message_callback('warning', sub { my $m = $_[0]->text; print STDERR "$m\n" unless $m =~ m/failed to validate barcode/; return 1; });
ok
(
    !App::Print::barcode->print
    (
        printer => 'test',
        protocol => 'barcode',
        type => 'barcode',
        data => [[1234567]]
    ),
    'caught long barcode'
);
ok
(
    !App::Print::barcode->print
    (
        printer => 'test',
        protocol => 'barcode',
        type => 'barcode',
        data => [[12345]]
    ),
    'caught short barcode'
);
ok
(
    !App::Print::barcode->print
    (
        printer => 'test',
        protocol => 'barcode',
        type => 'barcode',
        data => [[123.56]]
    ),
    'caught invalid barcode'
);
App::MsgLogger->message_callback
(
    'warning',
     sub
     {
         my $m = $_[0]->text;
         my $trim = qr/trimming long text/;
         if ($m =~ $trim)
         {
             like($m, $trim, 'caught long label');
         }
         else
         {
             print STDERR "$m\n";
         }
         return 1;
     }
);
ok
(
    App::Print::barcode->print
    (
        printer => 'test',
        protocol => 'barcode',
        type => 'label',
        data => ['test barcode that is too long to print on a label so it should not get passed through']
    ),
   'trimmed long label'
);

# create a file of barcodes
SKIP:
{
    my $file = 'test.bc';
    my $fh = IO::File->new(">$file");
    skip('failed to create barcode file', 1) unless defined($fh);
    my @bcs = ("barcode:123456\ttest label\tfrom file", "barcode:qazwsx\tsecond label\tstill in file", "label:this is a label, just a label");
    foreach my $b (@bcs)
    {
        $fh->print("$b\n");
    }
    $fh->close;
    ok(App::Print::barcode->print(printer => 'test', protocol => 'barcode',
                                  path => $file),
       'barcodes and label from file');
    unlink($file);
}

# remove local spool
rmtree('var');

# just see if we get anything
my $dp = GSCApp::Print::Barcode->default_barcode_printer;
ok($dp, "got default barcode printer: $dp");

exit(0);

# $Header$
