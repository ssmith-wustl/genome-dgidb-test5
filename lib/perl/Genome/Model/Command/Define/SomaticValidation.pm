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
            is => 'Genome::Model::Tools::DetectVariants2::Result::Base',
            doc => 'One or more BED files (or database ids) of the variants to validate',
            is_many => 1,
            shell_args_position => 3,
        },
        design => {
            is => 'Genome::FeatureList',
            doc => 'BED file (or database id) of the designs for the probes',
            shell_args_position => 1,
        },
        target => {
            is => 'Genome::FeatureList',
            doc => 'BED file (or database id) of the target region set',
            shell_args_position => 2,
        },
        tumor_sample => {
            is => 'Genome::Sample',
            doc => 'If there are no variants, specify the "tumor" sample directly',
        },
        normal_sample => {
            is => 'Genome::Sample',
            doc => 'If there are no variants, specify the "normal" sample directly',
        },
        region_of_interest_set => {
            is => 'Genome::FeatureList',
            doc => 'Specify this if reference coverage should be run on a different set than the target',
        },
        processing_profile => {
            is => 'Genome::ProcessingProfile::SomaticValidation',
            doc => 'Processing profile for the model',
        },
        groups => {
            is => 'Genome::ModelGroup',
            is_many => 1,
            doc => 'Group(s) to which to add the newly created model(s)',
        },
    ],
    has_transient_optional_input => [
        subjects => {
            is => 'Genome::Subject',
            is_many => 1,
            doc => 'The subjects of the models to create',
        },
        reference_sequence_build => {
            is => 'Genome::Model::Build::ReferenceSequence',
            doc => 'Reference used for the variant calls',
        },
    ],
    has_transient_optional_output => [
        result_model_ids => {
            is => 'Number',
            via => 'result_models',
            to => 'id',
            is_many => 1,
            doc => 'ID of the model created by this command',
        },
        result_models => {
            is => 'Genome::Model::SomaticValidation',
            is_many => 1,
            doc => 'model created by this command',
        },
    ],
    doc => 'define a new somatic validation model',
};

sub help_detail {
    return <<'EOHELP'
To set up the model to run the validation process, three pieces of information are needed: the design (as sent to the vendor), the target set (as received from the vendor), and the variants to be validated. Each of these constituent parts are tracked individually by the analysis system, and this model takes the individual pieces and links them together.

First, the individual pieces need to be added to the system. For the designs we send to the vendor and targets we get back from the vendor, the files are stored as feature lists. For the lists of variants, we track them as detect variants results, either directly from the Somatic Variation pipeline or from manual curation. Then the parts are assembled with this command. The two main commands to add the individual pieces are:

`genome feature-list create` to create the feature lists, once for the design, and once for the target set.

`genome model somatic-validation manual-result` to record the manually curated results, if necessary. (One per file of variants.)
EOHELP
;
}

sub execute {
    my $self = shift;

    #these two parameters are required to create a model
    my $variants_by_subject_id = $self->resolve_subjects or return;
    $self->resolve_processing_profile or return;

    #these parameters are optional until build time
    $self->resolve_reference_sequence_build;

    my @m;
    for my $subject ($self->subjects) {
        my @params = (
            subject => $subject,
            processing_profile => $self->processing_profile,
        );

        my @tumor_sample_ids = keys(%{ $variants_by_subject_id->{$subject->id} });
        if(@tumor_sample_ids != 1) {
            die $self->error_message('Expected one tumor sample for subject ' . $subject->__display_name__);
        }
        my $tumor_sample = Genome::Subject->get(\@tumor_sample_ids);

        my $control_sample;
        my $variant_results_by_type = {};
        unless($self->tumor_sample and not $self->normal_sample) {
            my @control_sample_ids = keys(%{ $variants_by_subject_id->{$subject->id}{$tumor_sample->id} });
            if(@control_sample_ids != 1) {
                die $self->error_message('Expected one control sample for subject ' . $subject->__display_name___);
            }

            $control_sample = Genome::Subject->get(\@control_sample_ids);

            my $variant_results = $variants_by_subject_id->{$subject->id}{$tumor_sample->id}{$control_sample->id};
            $variant_results_by_type = $self->resolve_variant_list_types(@$variant_results);
        }

        push @params, name => $self->name
            if defined $self->name;
        push @params, reference_sequence_build => $self->reference_sequence_build
            if defined $self->reference_sequence_build;
        push @params, design_set => $self->design
            if defined $self->design;
        push @params, target_region_set => $self->target
            if defined $self->target;
        push @params, snv_variant_list => $variant_results_by_type->{snv}
            if defined $variant_results_by_type->{snv};
        push @params, indel_variant_list => $variant_results_by_type->{indel}
            if defined $variant_results_by_type->{indel};
        push @params, sv_variant_list => $variant_results_by_type->{sv}
            if defined $variant_results_by_type->{sv};
        push @params, tumor_sample => $tumor_sample;
        push @params, normal_sample => $control_sample
            if defined $control_sample;

        if($self->region_of_interest_set) {
            push @params, region_of_interest_set => $self->region_of_interest_set;
        } elsif($self->target) {
            push @params, region_of_interest_set => $self->target;
        }

        my $m = Genome::Model->create(@params);
        return unless $m;
        push @m, $m;

        $self->status_message('Successfully defined model: '.$m->__display_name__);
    }

    $self->result_models(\@m);
    $self->status_message('New models: ' . join(',', map($_->id, @m)));
    if($self->groups) {
        for my $group ($self->groups) {
            $group->assign_models(@m);
        }
    }
    return scalar @m;
}

sub resolve_subjects {
    my $self = shift;

    if($self->tumor_sample or $self->normal_sample) {
        if($self->variants) {
            die $self->error_message('Please only supply tumor and normal sample if no variants are available.');
        }
        my $subject = $self->_resolve_subject_from_samples($self->tumor_sample, $self->normal_sample);
        $self->subjects([$subject]);

        return { $subject->id => { $self->tumor_sample->id => { ($self->normal_sample ? ($self->normal_sample->id => []) : ())}}};
    }

    my @subjects;
    my $variants_by_subject_id = {};

    for my $variant_list ($self->variants) {
        my ($subject, $tumor_sample, $control_sample) = $self->resolve_subject($variant_list);
        push @subjects, $subject unless exists $variants_by_subject_id->{$subject->id};

        $variants_by_subject_id->{$subject->id}{$tumor_sample->id}{$control_sample->id} ||= [];
        push @{ $variants_by_subject_id->{$subject->id}{$tumor_sample->id}{$control_sample->id} }, $variant_list;
    }

    $self->subjects(\@subjects);
    return $variants_by_subject_id;
}

sub resolve_subject {
    my $self = shift;
    my $potential_source = shift;

    my ($tumor_sample, $control_sample);

    if($potential_source->can('sample') and $potential_source->can('control_sample')) {
        #this is the expected case for manual results
        $tumor_sample = $potential_source->sample;
        $control_sample = $potential_source->control_sample;
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
                }
            }
        }
    }


    unless($tumor_sample or $control_sample) {
        $self->error_message('At least one sample is required to define a model. None found for ' . $potential_source->__display_name__);
        return;
    }

    #$self->tumor_sample($tumor_sample);
    #$self->normal_sample($control_sample);

    my $subject = $self->_resolve_subject_from_samples($tumor_sample, $control_sample);

    return ($subject, $tumor_sample, $control_sample) if wantarray;
    return $subject;
}

sub _resolve_subject_from_samples {
    my $self = shift;
    my $tumor_sample = shift;
    my $control_sample = shift;

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

    return $subject;
}

sub resolve_processing_profile {
    my $self = shift;

    return 1 if $self->processing_profile;

    my $pp;
    if($self->tumor_sample and not $self->normal_sample) {
        $pp = Genome::ProcessingProfile::SomaticValidation->default_single_bam_profile();
    } else {
        #Nov 2011 default Somatic Validation
        $pp = Genome::ProcessingProfile::SomaticValidation->default_profile();
    }

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

sub resolve_variant_list_types {
    my $self = shift;
    my @variant_results = @_;

    my $results_by_type = {};
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
                return;
            }

            ($variant_type) = $files[0] =~ /(\w+)\.hq/; #lame solution
        }

        $variant_type =~ s/s$//;
        if(exists $results_by_type->{$variant_type}) {
            $self->error_message('Multiple variant results have same type!');
            return;
        }
        $results_by_type->{$variant_type} = $variant_result;
    }

    return $results_by_type;
}

1;

