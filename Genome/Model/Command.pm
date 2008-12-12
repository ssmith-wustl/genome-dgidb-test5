package Genome::Model::Command;

use strict;
use warnings;

use Genome;

require Genome::Utility::FileSystem;
use Regexp::Common;

class Genome::Model::Command {
    is => 'Command',
    has => [
        model           => { is => 'Genome::Model', id_by => 'model_id' },
        model_id        => { is => 'Integer', doc => 'identifies the genome model by id' },
        model_name      => { is => 'String', via => 'model', to => 'name' },
    ],
    doc => "work with genome models",
};

sub command_name {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name unless $class eq __PACKAGE__;
    return 'genome model';
}

sub command_name_brief {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name_brief unless $class eq __PACKAGE__;
    return 'model';
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return unless $self;
    
    unless ($class->get_class_object->get_property_meta_by_name("model")->is_optional or $self->model) {
        if ($self->bare_args) {
            my $pattern = $self->bare_args->[0];
            if ($pattern) {
                my @models = Genome::Model->get(name => { operator => "like", value => '%' . $pattern . '%' });
                if (@models >1) {
                    $self->error_message(
                                         "No model specified, and multiple models match pattern \%${pattern}\%!\n"
                                         . join("\n", map { $_->name } @models)
                                         . "\n"
                                     );
                    $self->delete;
                    return;
                }
                elsif (@models == 1) {
                    $self->model($models[0]);
                }
            } else {
                # continue, the developer may set this value later...
            }
        } else {
            $self->error_message("No model or bare_args exists");
            $self->delete;
            return;
        }
    }
    return $self;
}

sub _verify_model {
    my $self = shift;

    unless ( $self->model_id ) {
        $self->error_message("No model id given");
        return;
    }

    unless ( $self->model_id =~ /^$RE{num}{int}$/ ) {
        $self->error_message( sprintf('Model id given (%s) is not an integer', $self->model_id) );
        return;
    }

    unless ( $self->model ) {
        $self->error_message( sprintf('Can\'t get model for id (%s) ', $self->model_id) );
        return;
    }

    return 1;
}

sub _sub_command_name_to_class_name_map{
    my $class = shift;
    return 
        map { my ($type) = m/::(\w+)$/; $type => $_ }
                $class->sub_command_classes();
}

sub _get_sub_command_class_name{
    my $class = shift;
    my $sub_command_name = $class->sub_command_delegator(@_);
    unless ($sub_command_name) {
        # The subclassing column's value was probably undef, meaning this sub-command
        # should be skipped
        return;
    }
    
    # Does the sub-command exist?
    my %sub_command_types = $class->_sub_command_name_to_class_name_map();
    
    #this takes the db name of the sub class, 'foo bar' and turns it into a Class equivalent name FooBar
    my $key;
    my @words = split(/[-_\s]/, $sub_command_name);
    $key .= ucfirst $_ foreach @words;

    my $sub_command_type = $sub_command_types{$key};
    unless ($sub_command_type) {
        return;
    }
    
    return $sub_command_type;
}


sub sub_command_delegator {
    # This method is used by the mid-level (like ::Build::ReferenceAlignment::AlignReads modules
    # to return the right sub-sub-class like ::Build::ReferenceAlignment::AlignReads::Maq
    my($class,%params) = @_;

    if (not defined $params{'model_id'}) {
        return;
    }

    my $model = Genome::Model->get(id => $params{'model_id'});
    unless ($model) {
        $class->error_message("Can't retrieve a Genome Model with ID ".$params{'model_id'});
        return;
    }

    # Which property on the model will tell is the proper subclass to call?
    unless ($class->can('command_subclassing_model_property')) {
        #$class->error_message("class $class did not implement command_subclassing_model_property()");
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

sub bsub_rusage { 
    # override for tasks which require LSF resource requirements
    '' 
}

sub create_directory {
    my ($self, $path) = @_;

    Genome::Utility::FileSystem->create_directory($path)
        or die;

    $self->status_message("Created directory: $path");

    return 1;
}

sub lock_resource {
    my ($self,%args) = @_;
    unless (Genome::Utility::FileSystem->lock_resource(%args)) {
        $self->error_message('Failed to lock_resource by command '. $self->command_name);
        die;
    }
    return 1;
}

sub unlock_resource {
    my ($self, %args) = @_;
    unless (Genome::Utility::FileSystem->unlock_resource(%args)) {
        $self->error_message('Failed to unlock_resource by command '. $self->command_name);
        die;
    }
    return 1;
}
1;

#$HeadURL$
#$Id$
