package Genome::ProcessingProfile::Command::List;

use strict;
use warnings;

use Genome;
use Genome::ProcessingProfile;

class Genome::ProcessingProfile::Command::List {
    is => 'Command::DynamicSubCommands',
    doc => 'list processing profiles by type'
};

sub _sub_commands_from { 'Genome::ProcessingProfile' }

sub _build_all_sub_commands {
    my $self = shift;

    # make the default commands per processing-profile
    my @subclasses = $self->SUPER::_build_all_sub_commands(@_);

    # add an extra one
    if ($self->class eq __PACKAGE__) {
        class Genome::ProcessingProfile::Command::List::All {
            is => 'Genome::ProcessingProfile::Command::List::Base',
            has => [
                subject_class_name  => {
                    is_constant => 1, 
                    value => 'Genome::ProcessingProfile' 
                },
                show => { default_value => 'id,type_name,name' },
            ],
            doc => 'list processing profiles'
        };

        # return the whole list
        push @subclasses, 'Genome::ProcessingProfile::Command::List::All';
    }

    return @subclasses;
}

sub _build_sub_command {
    my ($self,
        $class_name,            # Genome::ProcessingProfile::Command::List::Foo
        $delegating_class_name, # Genome::ProcessingProfile::Command::List
        $reference_class_name   # Genome::ProcessingProfile::Foo
    ) = @_;

    # the default _build_all_sub_commands() in the super class calls this

    # params start with id and name, then sequencing_platform,
    # and then are in alpha order
    my $params_list = 'id,name' . 
        join('', 
            map { ",$_" } 
            sort { 
                ($a eq 'sequencing_platform' ? 1 : 2)
                cmp
                ($b eq 'sequencing_platform' ? 1 : 2)
            }
            $reference_class_name->params_for_class
        );

    # the description has a plain-english version of the profile name
    my $name = $reference_class_name;
    $name =~ s/Genome::ProcessingProfile:://;
    my @words = map { $self->_command_name_for_class_word($_) } split(/::/,$name);

    # write the custom command for this processing profile
    class {$class_name} { 
        is => 'Genome::ProcessingProfile::Command::List::Base',
        has => [
            subject_class_name => { 
                is_constant => 1, 
                value => $reference_class_name
            },
            show => { default_value => $params_list },
        ],
        doc => "list @words processing profiles",
    };

    return $class_name;
}



1;

#$HeadURL$
#$Id$
