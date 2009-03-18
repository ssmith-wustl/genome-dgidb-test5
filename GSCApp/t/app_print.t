#!/gsc/bin/perl

use warnings FATAL => 'all';
use strict;

use GSCApp;
use GSCApp::Test;

plan tests => 8;

use App::Print;

my $mock = Test::MockModule->new('App::Print::lpr');
ok($mock, "got mock object");
$mock->mock(_run_lpr => sub { 
  my($class,%args) = @_;
  ok($args{cmdline}, 'found [' . (join ' ', @{$args{cmdline}}) . ']');
  return unless($args{cmdline});
  return 1;
});

my $bpd = GSCApp::Print::Barcode->daemon();
ok($bpd, 'got bpd');
ok(spool($bpd, makefile('barcode')), 'printed barcode');
ok(spool($bpd, makefile('label')), 'printed label');

exit;

sub spool {
  my $bpd = shift;
  my $file = shift;
  
  #LSF: Zebra printer test
  return unless($bpd->spool
  (
      path => $file . '',
      printer => 'barcode8'
  ));

  #LSF: Intermec printer test
  return unless($bpd->spool
  (
      path => $file . '',
      printer => 'barcode10'
  ));
  return 1;
}

sub makefile {
  my $type = shift;
  my $fh = &tempfile();
  if($type eq 'barcode') {
    print $fh "barcode:2k001D\tTest Barcode Printing 1\t2k001D\n";
    print $fh "barcode:2k001X\tTest Barcode Printing 2\t2k001X\n";
    print $fh "barcode:2k001j\tTest Barcode Printing 3\t2k001j\n";
    print $fh "barcode:2k001k\tTest Barcode Printing 4\t2k001k\n";
  } elsif($type eq 'label') {
    print $fh "label:2k001D Test Barcode\n";
    print $fh "label:2k001X Test Barcode\n";
    print $fh "label:2k001j Test Barcode\n";
    print $fh "label:2k001k Test Barcode\n"; 
  }
  $fh->close;
  return $fh;
}

sub tempfile {
    my $tmpdir = ($^O eq 'MSWin32' || $^O eq 'cygwin') ? '/temp' : $ENV{'TMPDIR'} || '/tmp';
    return File::Temp->new
    (
        DIR => $tmpdir,
        UNLINK => 1,
        TEMPLATE => App::Name->prog_name . '-XXXX'
    );
}

#$Header: /var/lib/cvs/auto_pipeline/ips.pl,v 1.1 2006/06/09 16:09:07 sleong Exp $
