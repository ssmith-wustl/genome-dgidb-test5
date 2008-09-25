#!/gsc/bin/perl

use strict;
use warnings;
use Test::More tests => 3;
use above 'Genome';

BEGIN {
        use_ok('Genome::Model::Tools::PhredPhrap::PhdToFasta');
}

my $path = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-PhredPhrap'; #directory for sample data and output
my $static = "$path/PhdToFasta/_fasta_output.static"; #static file for comparison to output
my %params =
(
    phd_dir => "$path/phd_dir/",
    phd_file => "$path/PhdToFasta/phd.txt",  
    fasta_file => "$path/PhdToFasta/fasta_output.txt",
    _error_file => "$path/PhdToFasta/error.txt", 
);

my $phd_to_fasta = Genome::Model::Tools::PhredPhrap::PhdToFasta->create(%params);

isa_ok($phd_to_fasta, "Genome::Model::Tools::PhredPhrap::PhdToFasta");

ok($phd_to_fasta->execute,'execute PhdToFasta');

(unlink $phd_to_fasta->fasta_file . ".qual" and 
 unlink $phd_to_fasta->fasta_file)              
                                   if ((-e $phd_to_fasta->fasta_file or 
                                        die("Output file was not created"))
                                   and (-s $phd_to_fasta->fasta_file == 
                                        -s $static or
                                        die("Generated file $phd_to_fasta->fasta_file does not match static file:$static")));
exit;
