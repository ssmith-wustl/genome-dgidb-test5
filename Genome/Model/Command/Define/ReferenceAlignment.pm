package Genome::Model::Command::Define::ReferenceAlignment;

use strict;
use warnings;

use Genome;
use Mail::Sender;

class Genome::Model::Command::Define::ReferenceAlignment {
    is => 'Genome::Model::Command::Define',
    has_optional => [
        reference_sequence_build_id => {
            is => 'Number',
            len => 11,
            doc => 'ID of the reference sequence to align against'
        },
        target_region_set_names => {
            is => 'Text',
            is_many => 1,
            doc => 'limit the model to take specific capture or PCR data'
        }
    ]
};

# TODO: remove this with ref seq placeholder package and ref align pp ref seq name attribute
# Attempt to find appropriate imported reference sequence build from processing profile's reference sequence name attribute

sub _resolve_imported_reference_sequence_from_pp_ref_seq_name {
    sub get_taxon_id_from_species_name {
        my $name = shift;
        my @taxons = Genome::Taxon->get('species_name' => $name);
        if ($#taxons == 0) {
            return $taxons[0]->taxon_id;
        }
        else {
            return;
        }
    }

    my ($self, $model) = @_;

    my $referenceSequenceBuild;
    my $ppIsRefAlign = ref($model->processing_profile) =~ /^Genome::ProcessingProfile::ReferenceAlignment/;
    my $ppHasRefSeqName = 
        $ppIsRefAlign &&
        defined($model->processing_profile->reference_sequence_name) &&
        length($model->processing_profile->reference_sequence_name) > 0;

    if ($ppIsRefAlign) {
        my $ppRsName = $model->processing_profile->reference_sequence_name;
        my $rsPrefix;
        my $rsSpeciesName;
        my $rsVersion;
        my $subjectId;
        # Search by prefix, species name, and version
        if($ppRsName =~ /^([^-]+)-(.+)-(?:(?:build|version|v)-?)?([^-]+)$/i) {
            $rsPrefix = $1;
            $rsSpeciesName = $2;
            $rsVersion = $3;
            $subjectId = get_taxon_id_from_species_name($rsSpeciesName);
            if (defined($subjectId)) {
                my @rsms = Genome::Model::ImportedReferenceSequence->get(
                    'subject_class_name' => 'Genome::Taxon',
                    'subject_id' => $subjectId);
                if ($#rsms == 0) {
                    my @rsbs = $rsms[0]->get(
                        'type_name' => 'imported reference sequence',
                        'prefix' => $rsPrefix,
                        'version' => $rsVersion);
                    if ($#rsbs == 0) {
                        $referenceSequenceBuild = $rsbs[0];
                    }
                }
            }
        }
        # Search by prefix and species name
        if (!defined($referenceSequenceBuild) && $ppRsName =~ /^([^-]+)-(.+)$/) {
            $rsPrefix = $1;
            $rsSpeciesName = $2;
            $subjectId = get_taxon_id_from_species_name($rsSpeciesName);
            if (defined($subjectId)) {
                my @rsms = Genome::Model::ImportedReferenceSequence->get(
                    'subject_class_name' => 'Genome::Taxon',
                    'subject_id' => $subjectId);
                if ($#rsms == 0) {
                    my @rsbs = $rsms[0]->get(
                        'type_name' => 'imported reference sequence',
                        'prefix' => $rsPrefix,
                        'version' => $rsVersion);
                    if ($#rsbs == 0) {
                        $referenceSequenceBuild = $rsbs[0];
                    }
                }
            }
        }
    }

    if(defined($referenceSequenceBuild)) {
        $model->reference_sequence_build($referenceSequenceBuild);
    }
    elsif($model->genome_model_id >= 0) {
        # Alert ehvatum by email that an appropriate imported reference sequence build could not be found
        my $msender = new Mail::Sender({
            'smtp' => 'gscsmtp.wustl.edu',
            'from' => 'ehvatum@genome.wustl.edu',
            'replyto' => 'ehvatum@genome.wustl.edu'});
        if(!$msender) {
            $self->warning_message('Failed to create Mail::Sender: ' . Mail::Sender::Error);
        }
        else {
            if (!$msender->Open({
                'to' => 'ehvatum@genome.wustl.edu',
                'subject' => 'AUTO: no ImportedReferenceSequence build for "' . $model->processing_profile . '"'})) {
                $self->warning_message('Failed to open Mail::Sender message: ' . $msender->{'error_message'});
            }
            else {
                my $sendLine;
                if ($ppIsRefAlign) {
                    if ($ppHasRefSeqName) {
                        $sendLine =
                            'Failed to find a Genome::Model::Build::ImportedReferenceSequence instance for model ' .
                            $model->genome_model_id . ' with processing_profile "' . $model->processing_profile->name .
                            '" having reference_sequence_name "' . $model->processing_profile->reference_sequence_name .
                            '".';
                    }
                    else {
                        $sendLine =
                            'Failed to find a Genome::Model::Build::ImportedReferenceSequence instance for model ' .
                            $model->genome_model_id . ": model's processing profile's reference_sequence_name " .
                            'attribute is empty or undefined.';
                    }
                }
                else {
                    $sendLine =
                        'Failed to find a Genome::Model::Build::ImportedReferenceSequence instance for model ' .
                        $model->genome_model_id . ": model's processing profile is not an instance of " .
                        'Genome::ProcessingProfile::ReferenceAlignment or an instance of a subclass of Genome::ProcessingProfile::ReferenceAlignment.';
                }
                $msender->SendLineEnc($sendLine);
                if (!$msender->Close()) {
                    $self->warning_message('Failed to send Mail::Sender message: ' . $msender->{'error_message'});
                }
            }
        }
    }
}

sub execute {
    my $self = shift;

    my $reference_sequence_build;
    if(defined($self->reference_sequence_build_id)) {
        my $retrieved = Genome::Model::Build->get($self->reference_sequence_build_id);
        if(!defined($retrieved)) {
            $self->error_message('Failed to find a build for reference_sequence_build_id "' . $self->reference_sequence_build_id . '".');
            return;
        }
        if(ref($retrieved) ne 'Genome::Model::Build::ImportedReferenceSequence') {
            $self->error_message('Build found for reference_sequence_build_id "' . $self->reference_sequence_build_id . '" is not a Genome::Model::Build::ImportedReferenceSequence.');
            return;
        }
        $reference_sequence_build = $retrieved;
    }

    my $result = $self->SUPER::_execute_body(@_);
    return unless $result;

    my $model = Genome::Model->get($self->result_model_id);
    unless ($model) {
        $self->error_message("No model generated for " . $self->result_model_id);
        return;
    }

    # TODO: Stop referring to processing profile reference sequence name & remove it.  Use the reference sequence build
    # supplied via the reference_sequence_build_id parameter to this command and default to NCBI-human-36 if reference_sequence_build_id
    # was not supplied.
    # This code is temporary.  It alerts us to ref seqs that lack proper models and builds as we transition away from ref seq placeholder.
    if(defined($reference_sequence_build)) {
        $model->reference_sequence_build($reference_sequence_build);
    }
    else {
        if(defined($model->processing_profile)) {
            $self->_resolve_imported_reference_sequence_from_pp_ref_seq_name($model);
        }
    }

    # LIMS is preparing actual tables for these in the dw, until then we just manage the names.
    my @target_region_set_names = $self->target_region_set_names;
    if (@target_region_set_names) {
        for my $name (@target_region_set_names) {
            my $i = $model->add_input(value_class_name => 'UR::Value', value_id => $name, name => 'target_region_set_name');
            if ($i) {
                $self->status_message("Modeling instrument-data from target region '$name'");
            }
            else {
                $self->error_message("Failed to add target '$name'!");
                $model->delete;
                return;
            }
        }
    }
    else {
        $self->status_message("Modeling whole-genome (non-targeted) sequence.");
    }


    return $result;
}

1;
