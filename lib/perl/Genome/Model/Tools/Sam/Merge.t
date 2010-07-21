#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Genome::Model::Tools::Sam::Merge;
use Test::More;
use File::Compare;

if (`uname -a` =~ /x86_64/){
    plan tests => 11;
} else{
    plan skip_all => 'Must run on a 64 bit machine';
}

my $dir = '/gsc/var/cache/testsuite/data/Genome-Tools-Sam-Merge';
my $input_normal = $dir. '/normal.tiny.bam';
my $input_tumor  = $dir. '/tumor.tiny.bam';
my $bam_index    = $dir. '/normal_tumor.tiny.bam.bai';

# step 1: test 1 file case

my $out_1_file = File::Temp->new(SUFFIX => ".bam" );

my $cmd_1 = Genome::Model::Tools::Sam::Merge->create(
    files_to_merge => [$input_normal],
    merged_file    => $out_1_file->filename,
    bam_index      => 0,
);

ok($cmd_1, "created command");
ok($cmd_1->execute, "executed");
ok(-s $out_1_file->filename, "output file is nonzero");
ok(!-s $out_1_file->filename.'.bai', 'Turn off .bai bam index generation');

# step 1: test >1 input file case

my $out_2_file = File::Temp->new(SUFFIX => ".bam" );

my $cmd_2 = Genome::Model::Tools::Sam::Merge->create(
    files_to_merge => [$input_normal, $input_tumor],
    merged_file    => $out_2_file->filename,
);

ok($cmd_2, "created command");
ok($cmd_2->execute, "executed");
ok(-s $out_2_file->filename, "output file is nonzero");
is(compare($bam_index, $out_2_file->filename.'.bai'), 0, 'The bam index is generated as expected'); 

unlink $out_2_file->filename.'.bai';

## email test
SKIP: {
    skip 'monitor_shellcmd test can be annoying', 3 unless($ENV{'MONITOR_SHELLCMD_TEST'});

    my $test_subcmd;

    ok($test_subcmd = File::Temp->new(SUFFIX => ".pl"), 'opening temp pl');
    $test_subcmd->autoflush(1);
    ok($test_subcmd->print(q|
#!/gsc/bin/perl

use strict;
use warnings;

use IO::Handle;

STDOUT->autoflush(1);

for (0..6) {
    sleep 1;

    if ($_ && $_ % 5 == 0) {
        sleep 7;
    }
    print $_ . "\n";
}
|),'writing temp pl');

    my $rv;
    ok($rv = Genome::Model::Tools::Sam::Merge->monitor_shellcmd({
        cmd => 'perl ' . $test_subcmd->filename
    }, 1, 5),'run temp pl');

};

