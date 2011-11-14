package Genome::ProcessingProfile::Command::Create;

use strict;
use warnings;
use Genome;

class Genome::ProcessingProfile::Command::Create {
    is => 'Command::SubCommandFactory',
    doc => 'Create a processing profile',
};

sub _sub_commands_from { 'Genome::ProcessingProfile' }

sub _sub_commands_inherit_from { 'Genome::ProcessingProfile::Command::Create::Base' }

sub _build_sub_command {
    my ($self, $class_name, @inheritance) = @_;
    my $target_class_name = $self->_sub_commands_from;

    my $subclass_name = $class_name;
    $subclass_name =~ s/Genome::ProcessingProfile::Command::Create:://;

    my $profile_string = Genome::Utility::Text::camel_case_to_string($subclass_name);
    $profile_string =~ s/:://;

    class {$class_name} {
        is => \@inheritance,
        has => [
            $self->_sub_commands_inherit_from->_properties_for_class(join('::', $target_class_name, $subclass_name)),
        ],
        doc => "Create a new profile for $profile_string",
    };
    return $class_name;
}
