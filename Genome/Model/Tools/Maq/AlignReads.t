#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Genome::Model::Tools::Maq::AlignReads;
use Test::More;
#tests => 1;

if (`uname -a` =~ /x86_64/){
    plan tests => 8;
} else{
    plan skip_all => 'Must run on a 64 bit machine';
}

my $expected_output = 2;

my $ref_seq = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq-AlignReads/all_sequences.bfa";
my $files_to_align = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq-AlignReads/single-solexa";
my $unaligned = "unaligned.out";
my $aligner_log = "aligner.log";
my $sol_flag = "y";
my $output_dir = File::Temp::tempdir(CLEANUP => 1);
my $force_fragments = 1;

##############
#TODO:  Subbing out aligner tool to reduce loc 
#my $asub = execute_alignment(ref_seq=>"fooseq");
#print 'asub: '.$asub;
#############

 
#Case 1: single read 
my $aligner = Genome::Model::Tools::Maq::AlignReads->create(
							 ref_seq_file => $ref_seq,
                                                         files_to_align_path => $files_to_align,
							 execute_sol2sanger => $sol_flag,
							 output_directory=> $output_dir
                                                        );

#execute the tool 
ok($aligner->execute,'AlignReads execution, single read solexa input with sol2sanger conversion.');

#check the number of files in the output directory, should be 2.
my @listing = glob($output_dir.'/*');
ok( scalar(@listing) eq $expected_output, "Number of output files expected = ".$expected_output );

#Case 2: paired end 

#get a new output dir
$output_dir = File::Temp::tempdir(CLEANUP => 1);
#get new input test data
$files_to_align = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq-AlignReads/paired-solexa";
#Add a pipe delimited test eventually...
#$files_to_align = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq-AlignReads/paired-solexa/s_1_1_sequence_test.txt|/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq-AlignReads/paired-solexa/s_1_2_sequence_test.txt";

$aligner = Genome::Model::Tools::Maq::AlignReads->create(
							 ref_seq_file => $ref_seq,
                                                         files_to_align_path => $files_to_align,
							 execute_sol2sanger => $sol_flag,
							 output_directory=> $output_dir
							);

#execute the tool 
ok($aligner->execute,'AlignReads execution, paired read solexa input with sol2sanger conversion.');

#check the number of files in the output directory, should be 2.
@listing = glob($output_dir.'/*');
ok( scalar(@listing) eq $expected_output, "Number of output files expected = ".$expected_output );


#Case 3: paired end, force fragment
#get a new output dir

#local testing
$output_dir = File::Temp::tempdir(CLEANUP => 1);
#$output_dir = "output";

#get new input test data
$files_to_align = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq-AlignReads/paired-solexa";

$aligner = Genome::Model::Tools::Maq::AlignReads->create(
							 ref_seq_file => $ref_seq,
                                                         files_to_align_path => $files_to_align,
							 execute_sol2sanger => $sol_flag,
							 force_fragments => $force_fragments,
							 output_directory=> $output_dir,
							);

#execute the tool 
ok($aligner->execute,'AlignReads execution, paired read solexa input with sol2sanger conversion, forcing fragments.');

#check the number of files in the output directory, should be 2.
@listing = glob($output_dir.'/*');
ok( scalar(@listing) eq $expected_output, "Number of output files expected = ".$expected_output );


#Case 4: test for dumping duplicate mismatch file
#get a new output dir
$output_dir = File::Temp::tempdir(CLEANUP => 1);
$expected_output = 3;
#get new input test data
$files_to_align = "/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq-AlignReads/paired-solexa";

$aligner = Genome::Model::Tools::Maq::AlignReads->create(
							 ref_seq_file => $ref_seq,
                                                         files_to_align_path => $files_to_align,
							 execute_sol2sanger => $sol_flag,
							 duplicate_mismatch_file => "mismatch",
							 output_directory=> $output_dir
							);

#execute the tool 
ok($aligner->execute,'AlignReads execution, paired read input with sol2sanger conversion, dump duplicates');

#check the number of files in the output directory, should be 3.
@listing = glob($output_dir.'/*');
#print "\n\nListing: ".join(", ",@listing)."\n\n";
ok( scalar(@listing) eq $expected_output, "Number of output files expected = ".$expected_output );



exit;



#TODO: use this sub instead of calling create everytime
sub execute_alignment {

	#my $self=shift;
        my %p = @_;
        my $ref_seq = $p{ref_seq};
        my $aligner_output_file = $p{aligner_output_file};
        return 'sub ref seq: '.$ref_seq;

my $aligner = Genome::Model::Tools::Maq::AlignReads->create(
                                                         ref_seq_file => $ref_seq,
                                                         files_to_align_path => $files_to_align,
                                                         execute_sol2sanger => $sol_flag,
                                                         output_directory=> $output_dir
                                                        );


}

