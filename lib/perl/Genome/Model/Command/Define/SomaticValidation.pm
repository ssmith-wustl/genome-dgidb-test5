package Genome::Model::Command::Define::SomaticValidation;

use strict;
use warnings;

use Genome;

use Cwd;
use File::Basename;

class Genome::Model::Command::Define::SomaticValidation {
    is => 'Command::V2',
    has_optional_input => [
        name => {
            is => 'Text',
            doc => 'A name for the model',
        },
        variants => {
            is => 'Genome::SoftwareResult', #TODO ideally these would all have share a DV2 base class
            doc => 'The DV2 results to validate',
            is_many => 1,
            shell_args_position => 3,
        },
        design => {
            is => 'Genome::FeatureList',
            doc => 'BED file of the designs for the probes',
            shell_args_position => 1,
        },
        target => {
            is => 'Genome::FeatureList',
            doc => 'BED file of the target region set',
            shell_args_position => 2,
        },
        processing_profile => {
            is => 'Genome::ProcessingProfile::SomaticValidation',
            doc => 'Processing profile for the model',
        },
    ],
    has_transient_optional_input => [
        subject => {
            is => 'Genome::Subject',
            doc => 'Subject of the model',
        },
        reference_sequence_build => {
            is => 'Genome::Model::Build::ReferenceSequence',
            doc => 'Reference used for the variant calls',
        },
        snv_result => {
            is => 'Genome::SoftwareResult',
            doc => 'The DV2 result with the snvs',
        },
        indel_result => {
            is => 'Genome::SoftwareResult',
            doc => 'The DV2 result with the indels',
        },
        sv_result => {
            is => 'Genome::SoftwareResult',
            doc => 'The DV2 result with the svs',
        },
    ],
    has_transient_optional_output => [
        result_model_id => {
            is => 'Number',
            doc => 'ID of the model created by this command',
        },
        result_model => {
            is => 'Genome::Model::SomaticValidation',
            id_by => 'result_model_id',
            doc => 'model created by this command',
        },
    ],
};

sub execute {
    my $self = shift;

    #these two parameters are required to create a model
    $self->resolve_subject or return;
    $self->resolve_processing_profile or return;

    #these parameters are optional until build time
    $self->resolve_reference_sequence_build;
    $self->resolve_variant_lists;

    my @params = (
        subject => $self->subject,
        processing_profile => $self->processing_profile,
    );

    push @params, name => $self->name
        if defined $self->name;
    push @params, reference_sequence_build => $self->reference_sequence_build
        if defined $self->reference_sequence_build;
    push @params, design_set => $self->design
        if defined $self->design;
    push @params, target_region_set => $self->target
        if defined $self->target;
    push @params, snv_variant_list => $self->snv_result
        if defined $self->snv_result;
    push @params, indel_variant_list => $self->indel_result
        if defined $self->indel_result;
    push @params, sv_variant_list => $self->sv_result
        if defined $self->sv_result;

    my $m = Genome::Model->create(@params);
    return unless $m;

    $self->status_message('Successfully defined model: '.$m->__display_name__);

    $self->result_model($m);
    return $m;
}

sub resolve_subject {
    my $self = shift;

    return 1 if $self->subject;

    my ($tumor_sample, $control_sample);
    SOURCE: for my $potential_source ($self->variants) {
        next unless $potential_source;

        if($potential_source->can('sample') and $potential_source->can('control_sample')) {
            #this is the expected case for manual results
            $tumor_sample = $potential_source->sample;
            $control_sample = $potential_source->control_sample;
            last SOURCE;
        } elsif($potential_source->can('users')) {
            my @users = $potential_source->users;
            my @user_objects = map($_->user, @users);
            my @candidate_objects = grep($_->isa('Genome::Model::Build::SomaticVariation'), @user_objects);
            if(@candidate_objects) {
                for my $c (@candidate_objects) {
                    if($c->can('normal_model') and $c->can('tumor_model')) {
                        #this is the expected case for results directly from somatic variation models
                        $tumor_sample = $c->tumor_model->subject;
                        $control_sample = $c->normal_model->subject;
                        last SOURCE;
                    }
                }
            }
        }
    }


    unless($tumor_sample or $control_sample) {
        $self->error_message('At least one sample is required to define a model.');
        return;
    }

    my $subject;
    if($tumor_sample) {
        if($control_sample and $tumor_sample->source ne $control_sample->source) {
            my $problem = 'Tumor and control samples do not appear to have come from the same individual.';
            my $answer = $self->_ask_user_question(
                $problem . ' Continue anyway?',
                300,
                "y.*|n.*",
                "no",
                "[y]es/[n]o",
            );
            unless($answer and $answer =~ /^y/) {
                $self->error_message($problem);
                return;
            }
        }

        $subject = $tumor_sample->source;
    } elsif($control_sample) {
        $subject = $control_sample->source;
    }

    $self->subject($subject);
    return $subject;
}

sub resolve_processing_profile {
    my $self = shift;

    return 1 if $self->processing_profile;

    my $pp = Genome::ProcessingProfile::SomaticValidation->get(2636889); #FIXME fill in real default

    $self->processing_profile($pp);
    return $pp;
}


sub resolve_reference_sequence_build {
    my $self = shift;

    return 1 if $self->reference_sequence_build;

    my $rsb;
    for my $potential_indicator ($self->design, $self->target, $self->variants) {
        next unless $potential_indicator;
        if($potential_indicator->can('reference')) {
            $rsb = $potential_indicator->reference;
            last;
        } elsif($potential_indicator->can('reference_build')) {
            $rsb = $potential_indicator->reference;
        }
    }

    $self->reference_sequence_build($rsb);
    return $rsb;
}

sub resolve_variant_lists {
    my $self = shift;

    my @variant_results = $self->variants;

    for my $variant_result (@variant_results) {
        my $variant_type;
        if($variant_result->can('variant_type')) {
            $variant_type = $variant_result->variant_type;
        } elsif ($variant_result->can('_variant_type')) {
            $variant_type = $variant_result->_variant_type;
        } else {
            my @files = glob($variant_result->output_dir . '/*.hq');
            if(scalar @files > 1) {
                $self->error_message('Multiple .hq files found in result ' . $variant_result->id . ' at ' . $variant_result->output_dir);
                return;
            }
            unless(scalar @files) {
                $self->error_message('No .hq file found in result ' . $variant_result->id . ' at ' . $variant_result->output_dir);
            }

            ($variant_type) = $files[0] =~ /(\w+)\.hq/; #lame solution
        }

        $variant_type =~ s/s$//;
        my $property = $variant_type . '_result';
        $self->$property($variant_result);
    }

    return 1;
}

1;

