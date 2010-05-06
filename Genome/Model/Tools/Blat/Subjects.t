#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use above 'Workflow';

use Test::More tests => 9;
#use Test::More skip_all => 'workflow and lsf issues taking a long time to test this';
use File::Compare;
use File::Temp;

BEGIN {
        use_ok ('Genome::Model::Tools::Blat::Subjects');
}

my $query_file = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Blat-Subjects/test.fa';
my $expected_psl = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Blat-Subjects/test.psl';
my $psl_path = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Blat-Subjects/test_tmp.psl';

SKIP: {
    skip 'only remove file if it exists with size', 1 unless -s $psl_path;
    ok(unlink ($psl_path), 'remove '. $psl_path);
}
my $blat_output_path = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Blat-Subjects/test_tmp.out';

SKIP: {
    skip 'only remove file if it exists with size', 1 unless -s $blat_output_path;
    ok(unlink ($blat_output_path),'remove '. $blat_output_path);
}
my $blat_params = '-mask=lower -out=pslx -noHead';
my $ref_seq_dir = Genome::Config::reference_sequence_directory() . '/refseq-for-test';

opendir(DIR,$ref_seq_dir) || die "Failed to open dir $ref_seq_dir";
my @ref_seq_files = map { $ref_seq_dir .'/'. $_ } grep { !/^all_seq/ } grep { /\.fa$/ } readdir(DIR);
closedir(DIR);

is(scalar(@ref_seq_files),3,'expected three input subject files');

my $blat = Genome::Model::Tools::Blat::Subjects->create(
                                                        query_file => $query_file,
                                                        subject_files => \@ref_seq_files,
                                                        psl_path => $psl_path,
                                                        blat_params => $blat_params,
                                                        blat_output_path => $blat_output_path
                                                  );
isa_ok($blat,'Genome::Model::Tools::Blat::Subjects');
ok($blat->execute,'execute '. $blat->command_name);
ok(!compare($psl_path,$expected_psl),'psl files are the same');
SKIP: {
    skip 'only remove file if it exists with size', 1 unless -s $psl_path;
    ok(unlink ($psl_path), 'remove '. $psl_path);
}
SKIP: {
    skip 'only remove file if it exists with size', 1 unless -s $blat_output_path;
    ok(unlink ($blat_output_path), 'remove '. $blat_output_path);
}
exit;
