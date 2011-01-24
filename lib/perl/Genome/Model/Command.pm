package Genome::Model::Command;

#:eclark 11/17/2009 Code review.

# Should not inherit from Genome::Sys.
# get_model_class* methods at the bottom should be in Genome::Model, not here.
# create_directory and bsub_rusage probably don't even belong in this class

use strict;
use warnings;

use Genome;

require Carp;
use Data::Dumper 'Dumper';
require Genome::Sys;
use Regexp::Common;

class Genome::Model::Command {
    is => ['Command','Genome::Sys'],
    has => [
        model           => { is => 'Genome::Model', id_by => 'model_id' },
        model_id        => { is => 'Integer', doc => 'identifies the genome model by id' },
        model_name      => { is => 'String', via => 'model', to => 'name' },
        name_pattern    => { is => 'String', shell_args_position => 99, is_optional => 1, doc => 'like expression to match against model name' }
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

# TODO: this is an improvement of the version in Command.pm
# Pull it up into that class if it works well.
sub class_for_sub_command
{
    my $self = shift;
    my $class = ref($self) || $self;
    my $sub_command = shift;

    return if $sub_command =~ /^\-/;

    my $ext = join("", map { ucfirst($_) } split(/-/, $sub_command));

    # Foo::Bar::Command w/ "baz" will try Foo::Bar::Command::Baz
    my $sub_class1 = $class . "::$ext";

    # Foo::Bar::Command w/ "baz" will try Foo::Bar::Baz::Command
    my $sub_class2;
    if ($class =~ /::Command$/) {
        $sub_class2 = $class;
        $sub_class2 =~ s/::Command//;
        $sub_class2 .= "::${ext}::Command";
    }

    for my $sub_class ($sub_class1, $sub_class2) {
        next unless $sub_class;
        my $meta = UR::Object::Type->get($sub_class); # allow in memory classes
        unless ( $meta ) {
            eval "use $sub_class;";
            if ($@) {
                if ($@ =~ /^Can't locate .*\.pm in \@INC/) {
                    #die "Failed to find $sub_class! $class_for_sub_command.pm!\n$@";
                    next;
                }
                else {
                    my @msg = split("\n",$@);
                    pop @msg;
                    pop @msg;
                    $self->error_message("$sub_class failed to compile!:\n@msg\n\n");
                    next;
                }
            }
        }
        elsif (my $isa = $sub_class->isa("Command")) {
            if (ref($isa)) {
                # dumb modules (Test::Class) mess with the standard isa() API
                if ($sub_class->SUPER::isa("Command")) {
                    return $sub_class;
                }
                else {
                    next;
                }
            }
            return $sub_class;
        }
        else {
            next;
        }
    }
    return;
}

sub sub_command_classes {
    my $self = shift;
    my @sscc = $self->SUPER::sub_command_classes(@_);
    my $class = $self->class;
    if ($class eq __PACKAGE__) {
        my $path = __FILE__;
        $path =~ s/Command.pm$//;
        $path .= '*/Command/';
        my @dirs = grep { -d $_ } glob($path);
        $path =~ s|/Genome/Model/.*$||;
        for my $dir(@dirs) {
            my $name = $dir;
            $name =~ s/$path//;
            $name =~ s|/|::|g;
            $name =~ s/^:://;
            $name =~ s/::$//;
            push @sscc, $name; 
        }
    }
    return @sscc;
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;
    
    if ( defined $self->model_id ) {
        unless ( $self->_verify_model ) {
            $self->delete;
            return;
        }
    }
    
    unless ($class->get_class_object->property_meta_for_name("model")->is_optional or $self->model) {
        if ($self->name_pattern) {
            my $pattern = $self->name_pattern;
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
            $self->error_message("No model or name_pattern exists");
            $self->delete;
            return;
        }
    }
    return $self;
}

sub _verify_model {
    my $self = shift;

    unless ( defined $self->model_id ) {
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

    return unless $params{model_id} =~ /^$RE{num}{int}$/;

    my $model = Genome::Model->get(id => $params{'model_id'})
        or return;

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

    Genome::Sys->create_directory($path)
        or die;

    $self->status_message("Created directory: $path");

    return 1;
}

sub _ask_user_question {
    my $self = shift;
    my $question = shift;
    my $timeout = shift || 60;
    my $input;
    eval {
        local $SIG{ALRM} = sub { die "Failed to reply to question '$question' with in '$timeout' seconds\n" };
        $self->status_message($question);
        $self->status_message("Please reply: 'yes' or 'no'");
        alarm($timeout);
        chomp($input = <STDIN>);
        alarm(0);
    };
    if ($@) {
        $self->warning_message($@);
        return;
    }
    unless ($input =~ m/yes|no/) {
        $self->error_message("'$input' is an invalid answer to question '$question'");
        return;
    }
    return $input;
}

#< Models Classes and Subclasses >#
sub get_model_classes {
    my @classes = Genome::Sys::get_classes_in_subdirectory_that_isa(
        'Genome/Model',
        'Genome::Model',
    );

    unless ( @classes ) { # bad
        Carp::confess("No model subclasses found!");
    }

    return @classes;
}

sub get_model_subclasses {
    # should confess in get_model_classes
    return map { m#::([\w\d]+)$# } get_model_classes();
}

sub get_model_type_names {
    # should confess in get_model_classes
    return map { Genome::Utility::Text::camel_case_to_string($_, ' ') } get_model_subclasses();
}

1;

#$HeadURL$
#$Id$
