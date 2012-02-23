package Genome::Model::Tools::AmpliconAssembly::CopyFromBuild;

use strict;
use warnings;

use Genome;

use Data::Dumper;
use File::Copy::Recursive;
use Regexp::Common;

class Genome::Model::Tools::AmpliconAssembly::CopyFromBuild {
    is => 'Command',
    has => [
    Genome::Model::Tools::AmpliconAssembly::Set->attributes_without_default_values,
    model_name => {
        is => 'Integer',
        is_optional => 1,
        doc => 'Use the latest completed build of this model name.',
    },
    model_id => {
        is => 'Integer',
        is_optional => 1,
        doc => 'Use the latest completed build of this model id.',
    },
    build_id => {
        is => 'Integer',
        is_optional => 1,
        doc => 'The id of the build to copy.',
    },
    copy_reads_only => {
        is => 'Boolean',
        default_value => 0,
        is_optional => 1,
        doc => 'Copy only the reads from the model.  Default is to copy all the contents of the build data directory.',
    },
    ],
};
#< Helps >#
sub help_brief {
    return 'Copy a build to a new directory';
}

sub help_detail {
    return <<EOS;
Copy an amplicon assembly from a build.  Indicate the build by id, or use a model's ( by id or name) last complete build.  The model's properties will also be copied, and saved.  To override a property, indicate those on the command line as well.
EOS
}

sub help_synopsis {
}

#< Command >#
sub sub_command_sort_position { 12; }

sub execute {
    my $self = shift;

    unless ( $self->directory ) {
        $self->error_message("Need directory to copy build to.");
        return;
    }
    
    my $build = $self->_resolve_build
        or return;
    
    my $amplicon_assembly = $self->_create_amplicon_assembly($build)
        or return;

    my ($from_directory, $to_directory);
    if ( $self->copy_reads_only ) {
        $from_directory = $build->chromat_dir;
        $to_directory = $amplicon_assembly->chromat_dir;
    }
    else { 
        $from_directory = $build->data_directory;
        $to_directory = $amplicon_assembly->directory;
    }

    $self->_recursive_copy($from_directory, $to_directory)
        or return;
    
    return 1;
}

sub _resolve_build {
    my $self = shift;
    
    my @build_resolvers = (qw/ build_id model_id model_name /);
    my @indicated_resolvers = grep { $self->$_ } @build_resolvers;
    
    if ( not @indicated_resolvers ) {
        $self->error_message(
            'No method indicated to get build for copying.  Please use one of the following: '.
            join(', ', @build_resolvers),
        );
        return;
    }
    elsif ( @indicated_resolvers > 1 ) {
        $self->error_message(
            sprintf(
                'Multiple ways indicated (%s) to get build for copying. Please use only one.',
                join(', ', @indicated_resolvers),
            )
        );
        return;
    }

    if ( $self->build_id ) {
        return unless $self->_validate_integer('build_id', $self->build_id);
        my ($build) = Genome::Model::Build->get(id => $self->build_id);
        unless ( $build ) {
            $self->error_message("Can't get build for build_id: ".$self->build_id);
            return;
        }
        return $build;
    }
    
    my $model;
    if ( $self->model_id ) {
        return unless $self->_validate_integer('model_id', $self->model_id);
        ($model) = Genome::Model->get(id => $self->model_id);
        unless ( $model ) {
            $self->error_message("Can't get model for model_id: ".$self->model_id);
            return;
        }
    }

    if ( $self->model_name ) {
        ($model) = Genome::Model->get(name => $self->model_name);
        unless ( $model ) {
            $self->error_message("Can't get model for model name ".$self->model_name);
            return;
        }
    }

    my $last_complete_build = $model->last_complete_build;
    unless ( $last_complete_build ) {
        $self->error_message(
            sprintf('No last complete build for model (%s %s)', $model->id, $model->name)
        );
        return;
    }

    return $last_complete_build;
}

sub _validate_integer {
    my ($self, $name, $int) = @_;

    unless ( $int =~ /^$RE{num}{int}$/ ) { # allow neg ints for testing
        $self->error_message("Invalid integer ($int) given for '$name'");
        return;
    }
    
    return 1;
}

sub _create_amplicon_assembly {
    my ($self, $build) = @_;
    
    my %params = ( 
        directory => $self->directory 
    );
    
    my @attribute_names = grep { $_ ne 'directory' } Genome::Model::Tools::AmpliconAssembly::Set->attribute_names;
    for my $attribute_name ( @attribute_names ) {
        my $value = $self->$attribute_name;
        if ( defined $value ) {
            $params{$attribute_name} = $value;
            next;
        }
        next unless $build->model->can($attribute_name);
        $value = $build->model->$attribute_name;
        next unless defined $value;
        $params{$attribute_name} = $value;
    }
    
    return Genome::Model::Tools::AmpliconAssembly::Set->create(%params);
}

sub _recursive_copy {
    my ($self, $from_dir, $to_dir) = @_;

    my $rv = eval { File::Copy::Recursive::dircopy($from_dir, $to_dir); };
    if ( not $rv ) {
        $self->error_message(
            sprintf(
                'Can\'t copy build directory (%s) to directory (%s): %s',
                $from_dir,
                $to_dir,
                ( $@ ? $@ : ( $! ? $! : 'No error set' )),
            )
        );
        return;
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
