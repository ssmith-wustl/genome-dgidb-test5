package Genome::Model::Event::Build::DeNovoAssembly::PostAssemble;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::DeNovoAssembly::PostAssemble {
    is => 'Genome::Model::Event::Build::DeNovoAssembly',
};

sub bsub_rusage {
    my $self = shift;
    return $self->processing_profile->bsub_usage;
}

sub execute {
    my $self = shift;

    unless ( $self->processing_profile->post_assemble ) { #shouldn't happen
	$self->error_message("Can't run de-novo-assembly post-assemble without declearing it in processing profile");
	return;
    }

    for my $post_assemble_part ( $self->processing_profile->post_assemble_parts ) {
	$self->_execute_tool ( $post_assemble_part );
    }

    return 1;
}

sub _execute_tool {
    my ( $self, $post_assemble_part ) = @_;

    #get tool name, convert to class name
    my ( $tool_name ) = $post_assemble_part =~ /^(\S+)/;
    $tool_name =~ s/-/ /g;
    my $class_name = Genome::Utility::Text::string_to_camel_case( $tool_name );

    #get params string, convert to hash, append assembly directory
    my ( $params_string ) = $post_assemble_part =~ /^\S+\s+(.*)/;
    my %params;
    if ( $params_string ) {
	%params = Genome::Utility::Text::param_string_to_hash( $params_string );
    }

    #append required param assembly_directory to %params
    $params{assembly_directory} = $self->build->data_directory;

    my $class = 'Genome::Model::Tools::'.ucfirst $self->processing_profile->assembler_base_name.'::'.$class_name;

    my $tool = $class->create ( %params );
    unless ( $tool ) {
	$self->error_message("Failed to create post assemble process: $post_assemble_part");
	return;
    }

    unless ( $tool->execute ) {
	$self->error_message("Failed to execute post assemble process: $post_assemble_part");
	return;
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
