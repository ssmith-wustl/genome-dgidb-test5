
package Genome::Model::Command;

use strict;
use warnings;

use above "Genome";

class Genome::Model::Command {
    is => ['Command'],
    english_name => 'genome model command',
    has => [
        model           => { is => 'Genome::Model', id_by => 'model_id' },
        model_id        => { is => 'Integer', doc => 'identifies the genome model by id' },
        model_name      => { is => 'String', via => 'model', to => 'name' },
        #limit_runs  => { is => 'Genome::RunChunk', is_many => 1 },
    ],
};

sub command_name {
    my $self = shift;
    my $class = ref($self) || $self;
    return 'genome-model' if $class eq __PACKAGE__;
    return $self->SUPER::command_name(@_);
}

sub help_brief {
    "modularized methods to operate on a genome model"
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return unless $self;
    
    if ( (!$self->model) and $self->bare_args->[0] ) {
        my $pattern = $self->bare_args->[0];
        my @models = Genome::Model->get(name => { operator => "like", value => '%' . $pattern . '%' });
        if (@models >1) {
            $self->error_message(
                "No model specified at creation time, and multiple models match pattern \%${pattern}\%!\n"
                . join("\n", map { $_->name } @models)
                . "\n"
            );
            return;
        }
        elsif (@models == 1) {
            $self->model($models[0]);
        }
        else {
            # continue, the developer may set this value later...
        }
    }
    
    return $self;
}

# Use the passed-in args to to determine the correct sub-sub command and create it
# Returns either the created command object, or "0 but true" to say that there was no
# sub-sub-command at that step.
sub Xcreate {
    my($class,%params) = @_;

    if ($class->can('_validate_params')) {
        unless ($class->_validate_params(%params)) {
            $class->error_message("Params did not validate, cannot create command $class");
            return;
        }
    }

    my $sub_command_class = $class->_get_sub_command_class_name(%params);
    if  ($sub_command_class and
         ($sub_command_class !~ m/::/)) {
        # returned a true value, but something that's not a class name
        return "0 but true";
    }

    my $self = $sub_command_class->create(%params,
                                          event_type => $sub_command_class->command_name,
                                          date_scheduled => UR::Time->now(),
                                          user_name => $ENV{'USER'});

    return $self;
}


sub _sub_command_name_to_class_name_map{
    my $class = shift;
    
    return map {
                    my ($type) = m/::(\w+)$/;
                    $type => $_
                }
                $class->sub_command_classes();
}

sub _get_sub_command_class_name{
    my $class = shift;
    
    #my $sub_command_name = $class->_get_sub_command_name(@_);
    my $sub_command_name = $class->sub_command_delegator(@_);
    unless ($sub_command_name) {
        # The subclassing column's value was probably undef, meaning this sub-command
        # should be skipped
        return "0 but true";
    }
    
    # Does the sub-command exist?
    my %sub_command_types = $class->_sub_command_name_to_class_name_map();

    my $sub_command_type = $sub_command_types{ucfirst($sub_command_name)};
    unless ($sub_command_type) {
#        $class->error_message("sub command $sub_command_type is not known");
      
        return;
    }
    
    return $sub_command_type;
}


# This method is used by the mid-level (like G::M::C::AddReads::AlignReads command modules
# To return the right sub-sub-class when the subclassing property is maq-ish
sub sub_command_delegator {
    my($class,%params) = @_;

    my $model = Genome::Model->get(id => $params{'model_id'});
    unless ($model) {
        $class->error_message("Can't retrieve a Genome Model with ID ".$params{'model_id'});
        return;
    }

    # Which property on the model will tell is the proper subclass to call?
    unless ($class->can('command_subclassing_model_property')) {
        $class->error_message("class $class did not implement command_subclassing_model_property()");
        return;
    }
    my $subclassing_property = $class->command_subclassing_model_property();

    unless ($model->can($subclassing_property)) {
        $class->error_message("class $class command_subclassing_model_property() returned $subclassing_property, but that is not a property of a model");
        return;
    }

    my $value = $model->$subclassing_property;
    if ($value =~ m/^maq/) {
        return 'maq';
    } else {
        return $value;
    }

}

# When add-reads schedules these jobs, it uses the mid-level command 
# (assign-run) and not the most specific one (assign-run solexa).  Since
# the bsub_rusage is defined in the most specific class, the mid-level
# command should get the value from there
sub bsub_rusage {
    my $class = shift;

    #my $command =  $self->_create_sub_command();
    my $subcommand = $class->_get_sub_command_class_name();
    if ($subcommand->can('bsub_rusage')) {
        return $subcommand->bsub_rusage;
    } else {
        return '';
    }
}


1;

