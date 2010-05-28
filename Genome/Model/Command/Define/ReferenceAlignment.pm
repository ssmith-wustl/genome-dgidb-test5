package Genome::Model::Command::Define::ReferenceAlignment;

use strict;
use warnings;

use Genome;
use Mail::Sender;

class Genome::Model::Command::Define::ReferenceAlignment {
    is => 'Genome::Model::Command::Define',
    has => [
        reference_sequence_build => {
            doc => 'ID or name of the reference sequence to align against'
        },
        target_region_set_names => {
            is => 'Text',
            is_optional => 1,
            is_many => 1,
            doc => 'limit the model to take specific capture or PCR instrument data'
        },
        region_of_interest_set_name => {
            is => 'Text',
            is_optional => 1,
            doc => 'limit coverage and variant detection to within these regions of interest',
        }
    ]
};

sub _resolve_imported_reference_sequence_build {
    my $self = shift;
    my $error = "";
    my $mail_error;
    my $reference_sequence_build;
    if (!defined($self->reference_sequence_build)) {
        $error = "Please supply the reference-sequence-build parameter.";
        $mail_error = "Reference_sequence_build parameter omitted."
    }
    else {
        if ($self->reference_sequence_build =~ /^\s*(\d+)\s*$/) {
            $reference_sequence_build = Genome::Model::Build::ImportedReferenceSequence->get(type_name => 'imported reference sequence', $1);
        }
        if (!defined($reference_sequence_build)) {
            # This is not the most efficient thing as it instantiates all imported reference sequences to query the name of each;
            # Genome::Model::Build::ImportedReferenceSequence->name should perhaps be cached if it remains calculated
            my @query_rfbs = Genome::Model::Build::ImportedReferenceSequence->get(type_name => 'imported reference sequence');
            foreach my $query_rfb (@query_rfbs) {
                if ($query_rfb->name() eq $self->reference_sequence_build) {
                    $reference_sequence_build = $query_rfb;
                    last;
                }
            }
        }
        if (!defined($reference_sequence_build)) {
            $error = 'Failed to find a reference_sequence_build with ID or name of "' . $self->reference_sequence_build . '".';
            $mail_error = $error;
        }
    }
    if (length($error) > 0) {
        my $msender = new Mail::Sender({
            'smtp' => 'gscsmtp.wustl.edu',
            'from' => 'ehvatum@genome.wustl.edu',
            'replyto' => 'ehvatum@genome.wustl.edu'});
        if (!$msender) {
            $self->warning_message('Failed to create Mail::Sender: ' . Mail::Sender::Error);
        }
        $mail_error = 'AUTO: genome model define reference_alignment with processing profile "' . $self->processing_profile_name . '" failed: ' . $mail_error;
        if (!$msender->Open({'to' => 'ehvatum@genome.wustl.edu', 'subject' => $mail_error})) {
            $self->warning_message('Failed to open Mail::Sender message: ' . $msender->{'error_message'});
        }
        else {
            $msender->SendLineEnc($mail_error);
            if (!$msender->Close()) {
                $self->warning_message('Failed to send Mail::Sender message: ' . $msender->{'error_message'});
            }
        }
        $self->error_message($error);
    }
    $self->{reference_sequence_build_object} = $reference_sequence_build;
    return $reference_sequence_build;
}

sub execute {
    my $self = shift;
    
    my $reference_sequence_build = $self->_resolve_imported_reference_sequence_build();
    defined($reference_sequence_build) or return;

    my $result = $self->SUPER::_execute_body(@_);
    return unless $result;

    my $model = Genome::Model->get($self->result_model_id);
    unless ($model) {
        $self->error_message("No model generated for " . $self->result_model_id);
        return;
    }

    $model->reference_sequence_build($reference_sequence_build);

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
    if ($self->region_of_interest_set_name) {
        my $name = $self->region_of_interest_set_name;
        my $i = $model->add_input(value_class_name => 'UR::Value', value_id => $name, name => 'region_of_interest_set_name');
        if ($i) {
            $self->status_message("Analysis limited to region of interest set '$name'");
        }
        else {
            $self->error_message("Failed to add region of interest set '$name'!");
            $model->delete;
            return;
        }
    } else {
        $self->status_message("Analyzing whole-genome (non-targeted) reference.");
    }

    return $result;
}

1;
