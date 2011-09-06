package Genome::Model::SomaticValidation::Command::IdentifyDnp;

class Genome::Model::SomaticValidation::Command::IdentifyDnp {
    is => 'Command::V2',
    doc => "Command line interface to create a Genome::Model::Build::SomaticValidation::IdentifyDnpResult",
    has_input => [
        build_id => {
            is => 'Number',
            doc => 'ID of a Somatic Validation Build.',
        },

    ],
    has_output => [
        dnp_result_id => {
            is => 'Text',
            doc => 'Resulting ID of a SoftwareResult for Identify DNP.',
            is_optional => 1,
        },
    ],
    has => [
        dnp_result => {
            is => 'Genome::Model::Build::SomaticValidation::IdentifyDnpResult',
            id_by => 'dnp_result_id',
            doc => "SoftwareResult containing the output of 'gmt somatic identify-dnp'.",
        },
        build => {
            is => 'Genome::Model::Build::SomaticValidation',
            id_by => 'build_id',
            doc => "Somatic Validation build that the DNP result will belong to and which procides the reads and proportion parameters.",
        },
    ],
};


sub help_detail {
    "This is a command line wrapper to create a Genome::Model::Build::SomaticValidation::IdentifyDnpResult. It is used by Genome::Model::Build::SomaticValidation's workflow."
}


sub execute {
    my $self = shift;

    my $proportion = $self->build->processing_profile->identify_dnp_proportion;
    unless (defined $proportion) {
        die $self->error_message("'identify_dnp_proportion' not specified on processing profile.");
    }

    my $result = Genome::Model::Build::SomaticValidation::IdentifyDnpResult->create(
        proportion => $proportion,
        build => $self->build,
    );

    my $rv = ($result ? 1 : 0);
    unless ($result) {
        $self->error_message('Failed to generate result.');
    }

    $self->dnp_result($result);

    return $rv;
}

1;
