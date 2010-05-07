package Genome::Model::Command::Define::RnaSeq;

use strict;
use warnings;

use Genome;
use Mail::Sender;

class Genome::Model::Command::Define::RnaSeq {
    is => 'Genome::Model::Command::Define',
    has_optional => [
        reference_sequence_build_id => {
            is => 'Number',
            len => 11,
            doc => 'ID of the reference sequence to use'
        }
    ]
};

# TODO: remove this with ref seq placeholder package and rna seq pp ref seq name attribute
# Attempt to find appropriate imported reference sequence build from processing profile's reference sequence name attribute

sub _resolve_imported_reference_sequence_from_pp_ref_seq_name {
    sub get_taxon_id_from_species_name {
        my $name = shift;
        my @taxons = Genome::Taxon->get('species_name' => $name);
        if($#taxons == 0)
        {
            return $taxons[0]->taxon_id;
        }
        else
        {
            return;
        }
    }

    my ($self, $model) = @_;

    my $referenceSequenceBuild;
    my $ppIsRnaSeq = ref($model->processing_profile) =~ /^Genome::ProcessingProfile::RnaSeq/;
    my $ppHasRefSeqName =
        $ppIsRnaSeq &&
        defined($model->processing_profile->reference_sequence_name) &&
        length($model->processing_profile->reference_sequence_name) > 0;

    if($ppIsRnaSeq)
    {
        my $ppRsName = $model->processing_profile->reference_sequence_name;
        my $rsPrefix;
        my $rsSpeciesName;
        my $rsVersion;
        my $subjectId;
        # Search by prefix, species name, and version
        if($ppRsName =~ /^([^-]+)-(.+)-(?:(?:build|version|v)-?)?([^-]+)$/i)
        {
            $rsPrefix = $1;
            $rsSpeciesName = $2;
            $rsVersion = $3;
            $subjectId = get_taxon_id_from_species_name($rsSpeciesName);
            if(defined($subjectId))
            {
                my @rsms = Genome::Model::ImportedReferenceSequence->get(
                    'subject_class_name' => 'Genome::Taxon',
                    'subject_id' => $subjectId);
                if($#rsms == 0)
                {
                    my @rsbs = $rsms[0]->get(
                        'type_name' => 'imported reference sequence',
                        'prefix' => $rsPrefix,
                        'version' => $rsVersion);
                    if($#rsbs == 0)
                    {
                        $referenceSequenceBuild = $rsbs[0];
                    }
                }
            }
        }
        # Search by prefix and species name
        if(!defined($referenceSequenceBuild) && $ppRsName =~ /^([^-]+)-(.+)$/)
        {
            $rsPrefix = $1;
            $rsSpeciesName = $2;
            $subjectId = get_taxon_id_from_species_name($rsSpeciesName);
            if(defined($subjectId))
            {
                my @rsms = Genome::Model::ImportedReferenceSequence->get(
                    'subject_class_name' => 'Genome::Taxon',
                    'subject_id' => $subjectId);
                if($#rsms == 0)
                {
                    my @rsbs = $rsms[0]->get(
                        'type_name' => 'imported reference sequence',
                        'prefix' => $rsPrefix,
                        'version' => $rsVersion);
                    if($#rsbs == 0)
                    {
                        $referenceSequenceBuild = $rsbs[0];
                    }
                }
            }
        }
    }

    if(defined($referenceSequenceBuild))
    {
        $model->reference_sequence_build($referenceSequenceBuild);
    }
    elsif($model->genome_model_id >= 0)
    {
        # Alert ehvatum by email that an appropriate imported reference sequence build could not be found
        my $msender = new Mail::Sender({
            'smtp' => 'gscsmtp.wustl.edu',
            'from' => 'ehvatum@genome.wustl.edu',
            'replyto' => 'ehvatum@genome.wustl.edu'});
        if(!$msender)
        {
            $self->warning_message('Failed to create Mail::Sender: ' . Mail::Sender::Error);
        }
        else
        {
            if(!$msender->Open({
                'to' => 'ehvatum@genome.wustl.edu',
                'subject' => 'AUTO: no ImportedReferenceSequence build for "' . $model->processing_profile . '"'}))
            {
                $self->warning_message('Failed to open Mail::Sender message: ' . $msender->{'error_message'});
            }
            else
            {
                my $sendLine;
                if($ppIsRnaSeq)
                {
                    if($ppHasRefSeqName)
                    {
                        $sendLine =
                            'Failed to find a Genome::Model::Build::ImportedReferenceSequence instance for model ' .
                            $model->genome_model_id . ' with processing_profile "' . $model->processing_profile->name .
                            '" having reference_sequence_name "' . $model->processing_profile->reference_sequence_name .
                            '".';
                    }
                    else
                    {
                        $sendLine =
                            'Failed to find a Genome::Model::Build::ImportedReferenceSequence instance for model ' .
                            $model->genome_model_id . ": model's processing profile's reference_sequence_name " .
                            'attribute is empty or undefined.';
                    }
                }
                else
                {
                    $sendLine =
                        'Failed to find a Genome::Model::Build::ImportedReferenceSequence instance for model ' .
                        $model->genome_model_id . ": model's processing profile is not an instance of " .
                        'Genome::ProcessingProfile::RnaSeq or an instance of a subclass of Genome::ProcessingProfile::RnaSeq.';
                }
                $sendLine .= '  (for RnaSeq model)';
                $msender->SendLineEnc($sendLine);
                if(!$msender->Close())
                {
                    $self->warning_message('Failed to send Mail::Sender message: ' . $msender->{'error_message'});
                }
            }
        }
    }
}

sub execute {
    my $self = shift;
    my $referenceSequenceBuild;
    if(defined($self->reference_sequence_build_id))
    {
        my $retrieved = Genome::Model::Build->get($self->reference_sequence_build_id);
        if(!defined($retrieved))
        {
            $self->error_message('Failed to find a build for reference_sequence_build_id "' . $self->reference_sequence_build_id . '".');
            return;
        }
        if(ref($retrieved) ne 'Genome::Model::Build::ImportedReferenceSequence')
        {
            $self->error_message('Build found for reference_sequence_build_id "' . $self->reference_sequence_build_id . '" is not a Genome::Model::Build::ImportedReferenceSequence.');
            return;
        }
        $referenceSequenceBuild = $retrieved;
    }
    $self->SUPER::_execute_body(@_) or return;
    # TODO: Stop referring to processing profile reference sequence name & remove it.  Use the reference sequence build
    # supplied via the reference_sequence_build_id parameter to this command and default to NCBI-human-36 if reference_sequence_build_id
    # was not supplied.
    # This code is temporary.  It alerts us to ref seqs that lack proper models and builds as we transition away from ref seq placeholder.
    my $model = Genome::Model->get($self->result_model_id);
    if($model)
    {
        if(defined($referenceSequenceBuild))
        {
            $model->reference_sequence_build($referenceSequenceBuild);
        }
        else
        {
            if(defined($model->processing_profile))
            {
                $self->_resolve_imported_reference_sequence_from_pp_ref_seq_name($model);
            }
        }
    }
    return 1;
}

1;
