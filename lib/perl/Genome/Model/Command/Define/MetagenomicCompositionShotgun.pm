package Genome::Model::Command::Define::MetagenomicCompositionShotgun;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Define::MetagenomicCompositionShotgun {
    is => 'Genome::Model::Command::Define',
    has => [
        subject_class_name => {
            is => 'Text',
            is_optional => 1,
            is_input => 1,
            default_value => 'Genome::Sample',
            doc => 'The Perl class name of the subject whose ID is subject_id'  
        },
        processing_profile_name => {
            is => 'Text',
            is_optional => 1,
            is_input => 1,
            default_value => 'human microbiome metagenomic alignment with samtools merge',
            doc => 'identifies the processing profile by name',
        },
        contamination_reference => {
            is => 'Text',
            is_optional => 1,
            is_input => 1,
            default_value => 'contamination-human',
            doc => 'the reference sequence to use for the contamination screen alignment',
        },
        metagenomic_references => {
            is => 'Text',
            is_many => 1,
            is_optional => 1,
            is_input => 1,
            default_value => ['microbial reference part 1 of 2', 'microbial reference part 2 of 2'],
            doc => 'the reference sequence to use for the metagenomic reference alignment',
        },
        # TODO: move these up, and make this subclass default to true for both values        
        assign_all_instrument_data => {
            default_value => 0,
            doc => 'assigns all available instrument data for the subject immediately',
        },
        build => {
            default_value => 0,
            doc => 'start building immediately',
        },
   ],
};

sub help_synopsis {
    return <<EOS;
genome model define metagenomic-composition-shotgun --subject-name H_LA-639-9080-cDNA-1

genome model define metagenomic-composition-shotgun \
    --subject-name H_LA-639-9080-cDNA-1 \
    --processing-profile-name "human microbiome metageomic shotgun"

genome model define metagenomic-composition-shotgun \
    --subject-name H_LA-639-9080-cDNA-1 \
    --processing-profile-name "human microbiome metageomic shotgun"
    --contamination-reference "contamination-human"
    --metagenomic-references "microbial reference 1 of 2","microbial reference 2 of 2"

    
EOS
}

# We'll eventually give explicit control over references used, though right now they're
# part of the processing profile.
#
# genome model define metagenomic-composition-shotgun \
#    --subject-name H_LA-639-9080-cDNA-1 \
#    --contamination-reference 12345
#    --metagenomic-references 678,910
#    --processing-profile-name "? ? metageomic shotgun"

sub help_detail {
    return "" 
}

sub type_specific_parameters_for_create {
    my $self = shift;

    my $contamination_screen_reference = Genome::Model->get(name => $self->contamination_reference);
    unless ($contamination_screen_reference){
        $self->error_message("Couldn't grab imported-reference-sequence model " . $self->contamination_reference . " to set default contamination_screen_reference");
        return;
    }
    my $contamination_screen_reference_build = $contamination_screen_reference->last_complete_build;
    unless($contamination_screen_reference_build){
        $self->error_message("Couldn't grab latest complete build from " . $self->contamination_reference . " the default contamination_screen_reference");
        return;
    }
    $self->status_message("Set contamination_reference build to " . $self->contamination_reference . " model's latest build");

    my @metagenomic_references;
    @metagenomic_references = map { Genome::Model->get(name => $_) } $self->metagenomic_references;
    unless ( (scalar $self->metagenomic_references) == grep { $_->isa('Genome::Model::ImportedReferenceSequence') } @metagenomic_references ){
        $self->error_message("Couldn't grab imported-reference-sequence models (".join(",", $self->metagenomic_references).") to set default metagenomic_screen_references");
        return;
    }
    my @metagenomic_reference_builds = map { $_->last_complete_build } @metagenomic_references;
    unless ( (scalar $self->metagenomic_references) == grep { $_->isa('Genome::Model::Build::ImportedReferenceSequence') } @metagenomic_reference_builds){
        $self->error_message("Couldn't grab imported-reference-sequence builds (".join(",", $self->metagenomic_references).") to set default metagenomic_screen_references");
        return;
    }
    $self->status_message("Set metagenomic reference builds to ".join(", ", $self->metagenomic_references)." models latest builds");

    my @params = (
        contamination_screen_reference => $contamination_screen_reference_build,
        metagenomic_references => \@metagenomic_reference_builds,
    );

    return @params;
}

1;

__END__

PLAN FORWARD:

1. This works:
genome model define metagenomic-composition-shotgun --subject-name H_LA-639-9080-CDNA-1 
genome model instrument-data assign -m ??? --all
genome model build start

2. This works, and does the above for you
genome model define metagenomic-composition-shotgun --subject-name H_LA-639-9080-CDNA-1 

3. This works: 
genome model define metagenomic-composition-shotgun --subject-name H_LA-639-9080-CDNA-1 --conamination-reference C --metagenomic-references M1,M2

