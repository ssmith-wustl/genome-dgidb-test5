# FIXME ebelter
#  Long: remove this and all define modeuls to have just one that can handle model inputs
package Genome::Model::Command::Define::ImportedReferenceSequence;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Define::ImportedReferenceSequence {
    is => 'Genome::Model::Command::Define',
    has => [
        fasta_file =>
        {
            is => 'Text',
            doc => "The full path and filename of the reference sequence fasta file to import"
        }
    ],
    has_optional => [
        prefix => {
            is => 'Text',
            doc => 'The source of the sequence, such as "NCBI".  Used to name the model.'
        }
        species_name => {
            is => 'Text',
            doc => 'The species name of the reference.  Maps to a taxon in the datbase.  Used to name the model.'
        },
        model_name => {
            is => 'Text',
            len => 255,
            doc => '$PREFIX-$SPECIES_NAME unless otherwise specified'
        },
   ],
};

sub help_synopsis {
    return "Prepares a fasta file to be used as a new refseq in processing profiles";
}

sub help_detail {
    return "Copies a fasta file out to the reference path, and then schedules jobs which will " . 
           "create appropriate BWA, Maq, and Samtools index files."
}

# We don't actually kick off a build.  All processing is performed on the machine running
# "genome model define imported-reference-sequence".  Some of the executables run
# in order to index the fasta and such are only available in the 64-bit environment,
# so we check to see that we are in the 64-bit environment early on.
sub execute {
    my $self = shift;

    unless(defined($self->model_name))
    {

    }
    # compose a model name, if one was not provided

    # check to see if the model exists

    my @new;
    # if it does not exist
        # ensure species is specified, tell them to select one
        # get the species, and ensure it is valid/real
        # make a model with that Genome::Taxon as the "subject"
        # use the single existing processing profile, named "imported reference", like the type_name
        my $m = Genome::Model->create();
        push @new, $m;

    # set the model's external_version_number and input_filename
    my $b = Genome::Model::Build->create(model => $m);
    unless ($b) {
        $self->error_message("Failed to generate a new build for model " 
                             . $m->__display_name__ . "!"
                             . Genome::Model::Build->error_message()
        );
        for (@new) { $_->delete }
        return;
    }
    $b->succeeded();

    return 1;
}

1;
