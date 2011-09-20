package Genome::Project;

use strict;
use warnings;
use Genome;
use Class::ISA;

class Genome::Project {
    is => 'Genome::Notable',
    id_generator => '-uuid',
    id_by => [
        id => { is => 'Text', }
    ],
    has => [
        name => {
            is => 'Text',
            doc => 'Name of the project',
        },
        creator => {
            is => 'Genome::Sys::User',
            via => 'parts',
            to => 'entity',
            where => [ 'entity_class_name' => 'Genome::Sys::User', role => 'creator', ],
            is_mutable => 1,
            is_many => 0,
        },
        user_ids => {
            is => 'Genome::Sys::User',
            via => 'parts',
            to => 'entity_id',
            where => [ 'entity_class_name' => 'Genome::Sys::User' ],
            is_mutable => 0,
            is_many => 1,
        },
    ],
    has_many_optional => [
        parts => {
            is => 'Genome::ProjectPart',
            is_mutable => 1,
            reverse_as => 'project',
            doc => 'All the parts that compose this project',
        },
        part_set => {
            is => 'Genome::ProjectPart::Set',
            is_calculated => 1,
        },
        parts_count => { 
            is => 'Number', 
            via => 'part_set', 
            to => 'count',
            doc => 'The number of parts associated with this project',
        },
        entities => {
            via => 'parts',
            to => 'entity',
            doc => 'All the objects to which the parts point',
        },
        models => {
            is => 'Genome::Model',
            via => 'parts',
            to => 'entity',
            where => [ 'entity_class_name like' => 'Genome::Model' ],
            is_mutable => 1,
            is_many => 1,
        },
        model_group => {
            is => 'Genome::ModelGroup',
            reverse_as => 'project',
        },
    ],
    table_name => 'GENOME_PROJECT',
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    doc => 'A project, can contain any number of objects (of any type)!',
};

sub create {
    my ($class, %p) = @_;

    my $self = $class->SUPER::create(%p);
    return if not $self;

    # Creator
    my $user_name = Genome::Sys->username;
    my $creator = Genome::Sys::User->get(username => $user_name);
    if ( not $creator ) {
        $self->error_message("Failed to create project. Failed to get user name for ".$user_name);
        return;
    }
    if ( not $self->creator($creator) ) {
        $self->error_message('Failed to add creator ('.$creator->username.') to  project');
        return;
    }

    # Name is unique. If apipe-builder is creating this project, rename the other.
    if ( my ($existing_project) = grep { $self->id ne $_->id } $class->get(name => $self->name) ) {
        if ( $user_name ne 'apipe-builder' ) {
            $self->error_message('There is already a project named "'.$existing_project->name.'" created by '.$existing_project->creator->username.'. Please choose a different name.');
            $self->delete;
            return;
        }

        # Rename other project
        my $i = 0;
        my $old_name = $existing_project->name;
        my $new_name;
        do {
            $new_name = $existing_project->creator->username.' '.$old_name.( $i ? '-'.$i : '' );
            $i++;
        } while $class->get(name => $new_name);

        $self->status_message('There is already a project with this name created by '.$existing_project->creator->username.'. It will be renamed.');
        $existing_project->rename($new_name);
        # TODO email user about name change??
    }

    # Model Group
    if ( not $self->model_group) {
        my $model_group = Genome::ModelGroup->create(
            name => $self->name,
            user_name => $self->creator->email,
            uuid => $self->id,
        );
        if ( not $model_group ) {
            $self->error_message('Failed to create corresponding model group fo project');
            $self->delete;
            return;
        }
        $self->status_message('Create corresponding model group: '.$model_group->id);
    }

    return $self;
}

sub rename {
    my ($self, $new_name) = @_;

    if ( not $new_name ) {
        $self->error_message('No new name given to rename model group');
        return;
    }

    my @projects = Genome::Project->get(name => $new_name);
    if ( @projects ) {
        $self->error_message("Failed to rename project (".$self->id.") from '".$self->name."' to '$new_name' because one already exists.");
        return;
    }

    my $old_name = $self->name;
    $self->name($new_name);

    if ( my $model_group = Genome::ModelGroup->get(uuid => $self->id) ) {
        $model_group->_rename($new_name);
    }

    $self->status_message("Renamed project from '$old_name' to '$new_name'");

    return 1;
}

sub get_parts_of_class {
    my $self = shift;
    my $desired_class = shift;
    croak $self->error_message('missing desired_class argument') unless $desired_class;

    my @parts = $self->parts;
    return unless @parts;

    my @desired_parts;
    for my $part (@parts) {
        my @classes = Class::ISA::self_and_super_path($part->entity->class);
        push @desired_parts, $part if grep { $_ eq $desired_class } @classes;
    }

    return @desired_parts;
}

sub delete {

    my ($self) = @_;

    for my $part ($self->parts) {
        $part->delete();
    }    

    return $self->SUPER::delete();
}


1;

