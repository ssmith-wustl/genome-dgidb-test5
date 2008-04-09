#!/gsc/bin/perl
########################################################################
# Module:        addreads.t
########################################################################

use strict;
use warnings;

use Data::Dumper;
use Genome::Model::Command;
use above 'Genome';

use Test::More tests => 2;

########################################################################
# Install DATA for testing:
########################################################################
# Reference sequence is already presumed to exist:
# my $refseqdir = "/gscmnt/sata114/info/medseq/reference_sequence";
my $refseqname = "refseq-for-test";

# Create a temp directory and expand testing sequences:
my $datadir = "/tmp/addreads";
# my $datadir = "/tmp/addreads-$$";
END {
     my $cmd = "/bin/rm -fr $datadir";
#    `$cmd`;
}
# `tar xvfz -C $datadir addreads.tgz`;


# create new test model
my $datestr = `date +"%y%m%d"`;
chomp $datestr;
my $create_command= Genome::Model::Command::Create->create(
     id                    => -999999,
     indel_finder          => 'maq0_6_3',
     model_name            => "test_$ENV{USER}_${datestr}",
     sample                => 'ley_aml_patient1_tumor',
     dna_type              => 'genome dna',
     align_dist_threshold  => '0',
     reference_sequence    => $refseqname,
     genotyper             => 'maq0_6_3',
     read_aligner          => 'maq0_6_3', 
    );

$create_command->execute();


my $new_model=Genome::Model->get(name =>"test_$ENV{USER}_${datestr}");
ok($new_model, "Model Creation");

# run add reads, part 1, as a whole unit
foreach my $dir (<$datadir/*>) {
    my $addreads_command = Genome::Model::Command::AddReads->create(
         model                 => $new_model,
         sequencing_platform   => 'solexa',
         full_path             => $dir
        );
    $addreads_command->execute();
}

my @modelevents = Genome::Model::Event->get(model_id => $new_model->genome_model_id);
ok(scalar @modelevents == 65, "AddReads Events Count");
foreach my $modelevent ( @modelevents ) {
    printf "%s %s %s %s\n",
           $modelevent->model_id,
           $modelevent->genome_model_event_id,
           $modelevent->run_id,
           $modelevent->event_type;
}


# verify correct functioning
# * alignment files generated
# * process--low-quality-alignments stage, how to test?
# * accept-reads          Add reads from all or part of an instrument run to the model
#verify database tables?

# how to verify part II of sequence?



# cleanup temporary files


# verify no-commit
UR::Context->rollback();


__END__
