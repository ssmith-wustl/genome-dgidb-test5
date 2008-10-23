#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use File::Temp;
use Test::More tests => 14;

BEGIN {
        use_ok('Genome::Model::Tools::WuBlast::Xdformat');
        use_ok('Genome::Model::Tools::WuBlast::Xdformat::Create');
        use_ok('Genome::Model::Tools::WuBlast::Xdformat::Append');
        use_ok('Genome::Model::Tools::WuBlast::Xdformat::Verify');
}

my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);
my $database = $tmp_dir .'/test_db';

my $ref_seq_dir = '/gscmnt/839/info/medseq/reference_sequences/refseq-for-test';
opendir(DIR,$ref_seq_dir) || die "Failed to open dir $ref_seq_dir";
my @ref_seq_files = grep { !/^all_seq/ } grep { /\.fa$/ } readdir(DIR);
closedir(DIR);
is(scalar(@ref_seq_files),3,'expected three ref seq files');

my @fasta_files = map {$ref_seq_dir .'/'. $_} @ref_seq_files;

# CREATE
my $create_success = Genome::Model::Tools::WuBlast::Xdformat::Create->create(
                                                                     database => $database,
                                                                     fasta_files => \@fasta_files,
                                                                 );
isa_ok($create_success,'Genome::Model::Tools::WuBlast::Xdformat::Create');
ok($create_success->execute,'execute command '. $create_success->command_name);

# The object should never get created because the database already exists.
my $create_fail = Genome::Model::Tools::WuBlast::Xdformat::Create->create(
                                                                          database => $database,
                                                                          fasta_files => \@fasta_files,
                                                                      );
is($create_fail, undef, 'Genome::Model::Tools::WuBlast::Xdformat::Create');
#ok(!$create_fail->execute,'failed to create duplicate database');

# APPEND
my $append_success = Genome::Model::Tools::WuBlast::Xdformat::Append->create(
                                                                             database => $database,
                                                                             fasta_files => \@fasta_files,
                                                                         );
isa_ok($append_success,'Genome::Model::Tools::WuBlast::Xdformat::Append');
ok($append_success->execute,'execute command '. $append_success->command_name);

# VERIFY
my $verify_success = Genome::Model::Tools::WuBlast::Xdformat::Verify->create(
                                                                     database => $database,
                                                                 );
isa_ok($verify_success,'Genome::Model::Tools::WuBlast::Xdformat::Verify');
ok($verify_success->execute,'execute command '. $verify_success->command_name);

# Remove a necessary database file and try to verify again(should fail)
unlink($database.'.xnt') || die "Failed to remove database file for test";
my $verify_fail = Genome::Model::Tools::WuBlast::Xdformat::Verify->create(
                                                                  database => $database,
                                                              );
isa_ok($verify_fail,'Genome::Model::Tools::WuBlast::Xdformat::Verify');
ok(!$verify_fail->execute,'expected verify to fail');

exit;

#$HeadURL$
#$Id$
