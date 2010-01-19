#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 2;
use File::Path;
use File::Basename;  
use File::Temp qw/ tempfile /;   
use File::Compare;
   



BEGIN
{
    use_ok ('Genome::Model::Tools::Fastq::RemoveN');
}

my $path = "/gsc/var/tmp/fasta/Hmp/illumina/t";
my $fastq_file      = "$path/contam.fastq";         #input data
my ($fh, $n_removed_file) = tempfile(UNLINK=>1);    #temporary output file
my $n_static = "$path/contam.N_REMOVED.static";     #static file for comparison
my $n_remover = Genome::Model::Tools::Fastq::RemoveN->create(fastq_file     =>  $fastq_file,
                                                             n_removed_file =>  $n_removed_file,);

my $out = $n_remover->execute;
ok (compare($n_removed_file,$n_static) == 0, "n remover runs ok");
