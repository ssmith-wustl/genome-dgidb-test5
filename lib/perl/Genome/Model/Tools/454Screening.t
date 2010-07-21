#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 3;


BEGIN {use_ok('Genome::Model::Tools::454Screening');}

my ($input_file,$database, $tmp_dir) = ( 
                                '/gsc/var/cache/testsuite/data/Genome-Model-Tools-454Screening/foo.fna',
                                '/gsc/var/lib/reference/set/2809160070/blastdb/ALL_blast.fa', 
                                Genome::Utility::FileSystem->create_temp_directory,);

#create
my $screen = Genome::Model::Tools::454Screening->create(
                                                                input_file => $input_file,
                                                                database => $database,
                                                                tmp_dir => $tmp_dir,
                                                            );
isa_ok($screen, 'Genome::Model::Tools::454Screening');
my $exc = $screen->execute();
ok($exc, "454 screening runs ok");
