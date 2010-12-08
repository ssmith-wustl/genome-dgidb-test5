package Genome::Model::Event::Build::DeNovoAssembly::Assemble;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::DeNovoAssembly::Assemble {
    is => 'Genome::Model::Event::Build::DeNovoAssembly',
};

sub bsub_rusage {
    my $self = shift;

    my $method = $self->processing_profile->assembler_name.'_bsub_rusage';
    if ( $self->processing_profile->can( $method ) ) {
	my $usage = $self->processing_profile->$method;
	return $usage;
    }
    $self->status_message( "bsub rusage not set for ".$self->processing_profile->assembler_name );
    return;
}

sub execute {
    my $self = shift;

    #pp specified assembler params - returns empty hash if no pp assembler param
    my %assembler_params = $self->processing_profile->sanitized_assembler_params;

    my $assembler_name = $self->processing_profile->assembler_name;

    #additional params from processing profile
    my $pp_param_method = $assembler_name . '_pp_params_for_build';
    if ( $self->processing_profile->can( $pp_param_method ) ) {
	my %pp_params = $self->processing_profile->$pp_param_method;
	%assembler_params = ( %assembler_params, %pp_params );
    }

    #additional params needed to be derived at build time
    my $pp_build_param_method = $assembler_name . '_params_to_derive_from_build';
    if ( $self->processing_profile->can( $pp_build_param_method ) ) {
	my %pp_build_params = $self->processing_profile->$pp_build_param_method( $self->build );
	%assembler_params = ( %assembler_params, %pp_build_params );
    }

    #run assemble
    $self->status_message("Running $assembler_name");
    my $assemble_tool = 'Genome::Model::Tools::' . ucfirst $assembler_name .'::Assemble';
    my $assemble = $assemble_tool->create( %assembler_params );

    unless ($assemble) {
        $self->error_message("Failed to create de-novo-assemble");
        return;
    }
    unless ($assemble->execute) {
        $self->error_message("Failed to execute de-novo-assemble execute");
        return;
    }
    $self->status_message("$assembler_name finished successfully");

    #methods to run after assembling .. not post assemble stage
    my $after_assemble_method = $assembler_name . '_after_assemble_methods_to_run';
    if ( $self->processing_profile->can( $after_assemble_method ) ) {
	$self->processing_profile->$after_assemble_method( $self->build );
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
