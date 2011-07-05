package Genome::Model::Event::Build::DeNovoAssembly::PostAssemble;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::DeNovoAssembly::PostAssemble {
    is => 'Genome::Model::Event::Build::DeNovoAssembly',
};

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

    $self->status_message('Post assemble: '.$post_assemble_part);

    #get tool name, convert to class name
    my ( $tool_name ) = $post_assemble_part =~ /^(\S+)/;
    $tool_name =~ s/-/ /g;
    my $class_name = Genome::Utility::Text::string_to_camel_case( $tool_name );
    my $class = 'Genome::Model::Tools::'.ucfirst $self->processing_profile->assembler_base_name.'::'.$class_name;

    $self->status_message('Class: '.$class);

    #get params string, convert to hash, append assembly directory
    my ( $params_string ) = $post_assemble_part =~ /^\S+\s+(.*)/;
    my %params;
    if ( $params_string ) {
        %params = Genome::Utility::Text::param_string_to_hash( $params_string );
    }
    $params{assembly_directory} = $self->build->data_directory;

    $self->status_message('Params: '.Data::Dumper::Dumper(\%params));

    my $tool = $class->create(%params);
    unless ( $tool ) {
        $self->error_message("Failed to create post assemble process: $post_assemble_part");
        return;
    }

    $tool->dump_status_messages(1);

    unless ( $tool->execute ) {
        $self->error_message("Failed to execute post assemble process: $post_assemble_part");
        return;
    }

    return 1;
}

1;

