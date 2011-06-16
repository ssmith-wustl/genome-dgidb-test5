package Genome::Model::Command::Define::MetagenomicCompositionShotgun;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Define::MetagenomicCompositionShotgun {
    is => ['Genome::Model::Command::Define', 'Genome::Command::Base', ],
    has => [
        contamination_reference_build => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            is_optional => 1,
            is_input => 1,
            doc => 'the reference sequence to use for the contamination screen alignment',
        },
        metagenomic_reference_builds => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            is_input => 1,
            doc => 'the reference sequence to use for the metagenomic reference alignment, use a comma separated list for multiple metagenomic references',
        },
        unaligned_metagenomic_alignment_reference_build => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            is_optional => 1,
            is_input => 1,
            doc => 'the reference sequence to use for the unaligned metagenomic alignment',
        },
        first_viral_verification_alignment_reference_build => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            is_optional => 1,
            is_input => 1,
            doc => 'the reference sequence to use for the first viral verification alignment',
        },
        second_viral_verification_alignment_reference_build => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            is_optional => 1,
            is_input => 1,
            doc => 'the reference sequence to use for the second viral verification alignment',
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
    --metagenomic-references "microbial reference part 1 of 2","microbial reference part 2 of 2"

    
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

sub _shell_args_property_meta {
    my $self = shift;
    return $self->Genome::Command::Base::_shell_args_property_meta(@_);
}

sub _resolve_param {
    my ($self, $param) = @_;

    my $param_meta = $self->__meta__->property($param);
    Carp::confess("Request to resolve unknown property '$param'.") if (!$param_meta);
    my $param_class = $param_meta->data_type;

    my $value = $self->$param;
    return unless $value; # not specified
    return $value if ref($value); # already an object

    my @objs = $self->resolve_param_value_from_text($value, $param_class);
    if (@objs != 1) {
        Carp::confess("Unable to find unique $param_class identified by '$value'. Results were:\n" .
            join('\n', map { $_->__display_name__ . '"' } @objs ));
    }
    $self->$param($objs[0]);
    return $self->$param;
}



sub type_specific_parameters_for_create {
    my $self = shift;

    my @params = (
        contamination_screen_reference => $self->contamination_reference_build,
        metagenomic_references => [$self->metagenomic_reference_builds],
        unaligned_metagenomic_alignment_reference => $self->unaligned_metagenomic_alignment_reference_build,
        first_viral_verification_alignment_reference => $self->first_viral_verification_alignment_reference_build,
        second_viral_verification_alignment_reference => $self->second_viral_verification_alignment_reference_build,
    );

    return @params;
}

sub execute {
    my $self = shift;
    $DB::single = 1;

    $self->metagenomic_reference_builds($self->_resolve_param('metagenomic_reference_builds'));
    unless(defined $self->metagenomic_reference_builds) {
        $self->error_message("Could not get a build for the metagenomic reference build provided");
        return;
    }

    if ($self->contamination_reference_build) {
        $self->contamination_reference_build($self->_resolve_param('contamination_reference_build'));
        unless(defined $self->contamination_reference_build) {
            $self->error_message("Could not get a build for the contamination reference build provided"); 
            return;
        }
    }

    if ($self->unaligned_metagenomic_alignment_reference_build) {
        $self->unaligned_metagenomic_alignment_reference_build($self->_resolve_param('unaligned_metagenomic_alignment_reference_build'));
        unless(defined $self->unaligned_metagenomic_alignment_reference_build) {
            $self->error_message("Could not get a build for the unaligned metagenomic alignment reference build provided");
            return;
        }
    }

    if ($self->first_viral_verification_alignment_reference_build) {
        $self->first_viral_verification_alignment_reference_build($self->_resolve_param('first_viral_verification_alignment_reference_build'));
        unless(defined $self->first_viral_verification_alignment_reference_build) {
            $self->error_message("Could not get a build for the first viral verification alignment reference build provided");
            return;
        }
    }

    if ($self->second_viral_verification_alignment_reference_build) {
        $self->second_viral_verification_alignment_reference_build($self->_resolve_param('second_viral_verification_alignment_reference_build'));
        unless(defined $self->second_viral_verification_alignment_reference_build) {
            $self->error_message("Could not get a build for the second viral verification alignment reference build provided");
            return;
        }
    }

    # run Genome::Model::Command::Define execute
    my $super = $self->super_can('_execute_body');
    return $super->($self,@_);
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

