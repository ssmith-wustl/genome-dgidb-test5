#!/gsc/bin/perl
#!/gsc/bin/perl -d:ptkdb
########################################################################
# File:      fastadiff.t
# Content:   Testing for functionality of command:
#               genome-model tools apply-diff-to-fasta ...
########################################################################

use strict;
use warnings;

use Data::Dumper;
use File::Compare;

use Test::More tests => 4;

########################################################################
sub runfastadiff
  {
  my ($ref, $diff, $compareto) = @_;    # $compareto undef if error expected.
  my $outfile = "/tmp/fastadiff.fasta";
  unlink $outfile if (-e $outfile);

  my $cmd = sprintf "%s --input=%s --diff=%s --output=%s",
                    "genome-model tools apply-diff-to-fasta",
                    $ref, $diff, $outfile;
# print ">> $cmd\n";
  my @output=`$cmd`;
  my $ret = $?;
  if ( ! defined $compareto )
    {
    return 0 if ( $ret != 0  &&  ! -e $outfile );
    return 1;
    }
  return 1 if ( $ret != 0 || ! -r $outfile );
  return 0 if (compare($outfile,$compareto) == 0);
  return 1;
  }

########################################################################
# To Test:
#   * Sequences with no indels.
#   * Character prepend/append.
#   * Multi-character deletes/inserts.
#   * Multi-character replacements of different length.
#   * Deletes output file on error.
#   * Multiple line inserts/deletes.
#   * Verifies delete text (case insensitive).
#   * Handles sequence descriptions.
#   * Handles sequence labels of varying format.
#   * Really this should handle replacements.
########################################################################
ok(runfastadiff("simple.fasta", "/dev/null", "simple.fasta")==0, "unchanged");
ok(runfastadiff("simple.fasta", "simple1.diff", "simple1.fasta")==0, "simple1: prepend/append, multiple proximal ops, multiple character ops");
ok(runfastadiff("simple.fasta", "simple2.diff", undef)==1, "simple2: detects");
ok(runfastadiff("multiline.fasta", "multiline1.diff", "multiline1.fasta")==1, "multiline: inserts/deletes");

########################################################################
0;
