#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Genome::Model::Tools::Sam::Merge;
use Test::More tests => 3;

my $input = '/gsc/var/cache/testsuite/data/Genome-Tools-Sam-MarkDuplicates/sample.bam';

# step 1: test 1 

my $tmp_dir = File::Temp->newdir( "MarkDuplicates_XXXXX",
                                  DIR => '/gsc/var/cache/testsuite/running_testsuites/', 
                                  CLEANUP => 1 );


my $output_file = File::Temp->new(SUFFIX => ".bam", DIR => $tmp_dir);
my $metrics_file = File::Temp->new(SUFFIX => ".metrics", DIR => $tmp_dir);
my $log_file = File::Temp->new(SUFFIX => ".log", DIR => $tmp_dir);

#uncomment to inspect output 
#$log_file->unlink_on_destroy(0);
#$output_file->unlink_on_destroy(0);
#$metrics_file->unlink_on_destroy(0);
#$log_file->unlink_on_destroy(0);

my $cmd_1 = Genome::Model::Tools::Sam::MarkDuplicates->create(file_to_mark=>$input,
                                                              marked_file=>$output_file->filename,
                                                              metrics_file=>$metrics_file->filename,
                                                              log_file=>$log_file->filename,
                                                              tmp_dir=>$tmp_dir->dirname,
                                                              remove_duplicates=>1,
                                                              max_jvm_heap_size=>2,        
                                                            );


ok($cmd_1, "created command");
ok($cmd_1->execute, "executed");
ok(-s $output_file->filename, "output file is nonzero");
