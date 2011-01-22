package Genome::ProcessingProfile::SomaticVariation;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::SomaticVariation{
    is => 'Genome::ProcessingProfile',
    has_param => [
        snv_detection_strategy => {
            doc => "Snv detector strategy string",
        },
        indel_detection_strategy => {
            doc => "Indel detector strategy string",
        },
        sv_detection_strategy => {
            doc => "SV detector strategy string",
        },
    ],
};

sub create {
    my $self = shift;
    my @errors;
    my $snv_strat = Genome::Model::Tools::DetectVariants2::Strategy->get($self->snv_detection_strategy) if defined($self->snv_detection_strategy);
    $self->status_message("Validating snv_detection_strategy");
    push @errors, $snv_strat->__errors__;
    $snv_strat->delete;
    my $sv_strat = Genome::Model::Tools::DetectVariants2::Strategy->get($self->sv_detection_strategy) if defined($self->sv_detection_strategy);
    $self->status_message("Validating snv_detection_strategy");
    push @errors, $sv_strat->__errors__;
    $sv_strat->delete;
    my $indel_strat = Genome::Model::Tools::DetectVariants2::Strategy->get($self->indel_detection_strategy) if defined($self->indel_detection_strategy);
    $self->status_message("Validating snv_detection_strategy");
    push @errors, $indel_strat->__errors__;
    $indel_strat->delete;
    if (scalar(@errors)) { 
        die @errors;
    }
    return $self->SUPER::create(@_);
}
sub _initialize_build {
    my($self,$build) = @_;
    die "This is not yet implemented.";
}

sub _resolve_workflow_for_build {
    my $self = shift;
    my $build = shift;
    die "This is not yet implemented.";
}

sub _map_workflow_inputs {
    my $self = shift;
    my $build = shift;
    die "This is not yet implemented.";
}

1;
