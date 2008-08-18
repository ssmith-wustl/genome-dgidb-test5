#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Test::More tests => 8;
use Text::Diff;
use File::Temp;


BEGIN {
    use_ok('Genome::Utility::SeqCleanReport::Reader');
    use_ok('Genome::Utility::SeqCleanReport::Writer');
}

use FindBin qw($Bin);

my $file = "$Bin/test.cln";

my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);
my $out_file = "$tmp_dir/out.cln";

my $reader = Genome::Utility::SeqCleanReport::Reader->create(
                                                             file => $file,
                                                         );
isa_ok($reader,'Genome::Utility::SeqCleanReport::Reader');
is($reader->separator,"\t",'separator');
is($reader->file,$file,'file accessor');

my $writer = Genome::Utility::SeqCleanReport::Writer->create(
                                                             file => $out_file,
                                                         );
isa_ok($writer,'Genome::Utility::SeqCleanReport::Writer');
is($writer->file,$out_file,'file accessor');
while (my $record = $reader->next) {
    $writer->write_record($record);
}
$writer->close;
$reader->close;

my $diff = `diff -b  $file $out_file`;
is($diff,'','Files are the same');


exit;
