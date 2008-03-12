#!/gsc/bin/perl
########################################################################
# File:      fastadiff.t
# Content:   Testing for functionality of command:
#               genome-model tools apply-diff-to-fasta ...
########################################################################
# Comments on functionality / todo's:
#   * Verify of delete text could be case insensitive.
#   * Verify sequence label acceptance criteria.
########################################################################

use strict;
use warnings;

use Data::Dumper;
use File::Compare;
use FindBin;

use Test::More tests => 8;

########################################################################
sub runfastadiff
  {
  my ($ref, $diff, $compareto) = @_;
  my $outfile = "/tmp/fastadiff.fasta";
  unlink $outfile if (-e $outfile);

  my $cmd = sprintf "%s --input=%s --diff=%s --output=%s",
                    "genome-model tools apply-diff-to-fasta",
                    $ref, $diff, $outfile;
  print ">> $cmd\n";
  my @output=`$cmd`;
  my $ret = $?;
  my $retval = 0;
  if ( ! defined $compareto )
    { $retval = 1 if ( $ret == 0 || -e $outfile ); }
  else
    { $retval = 1 if ( $ret != 0 || ! -r $outfile || compare($outfile,$compareto) != 0 ); }
  return $retval;
  }

########################################################################
sub fastadifftest
  {
  my $text = shift @_;
  ok(runfastadiff(@_)==0, $text);
  }

########################################################################
# Test Manifest:
#   unchanged  - multiple sequences w/ no changes.
#   simple1    - prepend/append; multi-character delete/insert;
#                delete/insert at same loc (separate indels);
#                replace (delete/insert at same loc);
#                seq. descriptions maintained.
#   simple2a   - error if delete text does not match.
#   simple2b   - error if insertion is out of sequence range.
#   simple2c   - error if diff ops are unused.
#   simple2d   - error if sequence indels are out of order.
#   simple2e   - error if deletion is out of sequence range.
#   multiline1 - multiple line insert/deletes.
########################################################################
sub main
  {
  my $tpath = $FindBin::Bin . "/fastadiff.d";

  fastadifftest "unchanged",
                "$tpath/simple.fasta",
                "/dev/null",
                "$tpath/simple.fasta";
  fastadifftest "simple1: prepend/append; multi-char ops; etc.",
                "$tpath/simple.fasta",
                "$tpath/simple1.diff",
                "$tpath/simple1.fasta";
  foreach my $expect_fail (qw/simple2a simple2b simple2c simple2d simple2e/)
    {
    fastadifftest "$expect_fail: handling error conditions",
                  "$tpath/simple.fasta",
                  "$tpath/${expect_fail}.diff",
                  undef;
    }
  fastadifftest "multiline: inserts/deletes",
                "$tpath/multiline.fasta",
                "$tpath/multiline1.diff",
                "$tpath/multiline1.fasta";
  }

########################################################################
main @ARGV;
