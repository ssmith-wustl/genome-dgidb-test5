#!/gsc/bin/perl
########################################################################
# Module:        addreads.t
########################################################################

use strict;
use warnings;

use Data::Dumper;
use Genome::Model::Command;
use above 'Genome';

use Test::More tests => 1;

########################################################################
# determine/generate data:
my $refseqdir = "/gscmnt/sata114/info/medseq/reference_sequence";
my $refseqname = "refseq-for-test";

#junky data... >= 2 runs of stuff


# create new test model
my $datestr = `date +"%y%m%d"`;
chomp $datestr;
my $model = Genome::Model::Command::Create->create(
        'model-name'            => "test_$ENV{USER}_${datestr}",
        '--sample'                => 'ley_aml_patient1_tumor',
        '--dna-type'              => 'genomic dna',
        '--align-dist-threshold'  => '0',
        '--reference-sequence'    => 'refseq-for-test',
        '--indel-finder'          => 'maq0_6_3',
        '--genotyper'             => 'maq0_6_3',
        '--read-aligner'          => 'maq0_6_3'
        );
$model->execute();

# run add reads, part 1




# verify correct functioning
# * alignment files generated
# * process--low-quality-alignments stage, how to test?
# * accept-reads          Add reads from all or part of an instrument run to the model
#verify database tables?

# how to verify part II of sequence?



# cleanup temporary files


# verify no-commit



__END__
