package Genome::Model::Event::Build::DeNovoAssembly::Assemble;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::DeNovoAssembly::Assemble {
    is => 'Genome::Model::Event::Build::DeNovoAssembly',
};

sub bsub_rusage {
    return $_[0]->build->assembler_rusage;
}

sub execute {
    my $self = shift;

    my $build = $self->build;
    my $processing_profile = $self->processing_profile;

    $self->status_message('Assemble '.$build->__display_name__);

    my $assembler_class = $processing_profile->assembler_class;
    $self->status_message('Assembler class: '. $assembler_class);

    my %assembler_params = $build->assembler_params;
    $self->status_message('Assembler params: '.Data::Dumper::Dumper(\%assembler_params));

    my $before_assemble = $build->before_assemble;
    if ( not $before_assemble ) {
        $self->error_message('Failed to run before assemble for '.$build->__display_name__);
        return;
    }

    my $assemble = $assembler_class->create(%assembler_params);
    unless ($assemble) {
        $self->error_message("Failed to create de-novo-assemble");
        return;
    }
    unless ($assemble->execute) {
        $self->error_message("Failed to execute de-novo-assemble execute");
        return;
    }
    $self->status_message('Assemble...OK');

    my $after_assemble = $build->after_assemble;
    if ( not $after_assemble ) {
        $self->error_message('Failed to run after assemble for '.$build->__display_name__);
        return;
    }

    return 1;
}

1;

