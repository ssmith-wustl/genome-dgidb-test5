package Genome::Site::WUGC::Observers::Project;

Genome::Project->add_observer(
    aspect => 'create',
    callback => \&create_callback,
);

Genome::Project->add_observer(
    aspect => 'delete',
    callback => \&delete_callback,
);

Genome::Project->add_observer(
    aspect => 'name',
    callback => \&rename_callback,
);

sub create_callback {
    my ($self, $construction_method) = @_;
    my $class = $self->class;

    # Set project creator
    my $user_name = Genome::Sys->username;
    my $creator = Genome::Sys::User->get(username => $user_name);
    unless ($creator) {
        $self->delete;
        die "Failed to create project, could not find user $user_name";
    }

    unless ($self->creator($creator)) {
        $self->delete;
        die "Failed to add creater '$user_name' to project";
    }

    # Make sure name is unique. Fail if name is not unique, but rename any conflicting
    # projects if this project is being created by apipe-builder.
    my ($existing_project) = grep { $self->id ne $_->id } $class->get(name => $self->name);
    if ($existing_project) {
        if ($user_name eq 'apipe-builder') {
            my $i = 0;
            my $old_name = $existing_project->name;
            my $new_name;
            do { 
                $new_name = $existing_project->creator->username . ' ' . $old_name .
                    ($i ? '-'.$i : '');
                $i++;
            } while $class->get(name => $new_name);

            $self->status_message("There is another project with name " . $self->name . 
                " created by " . $existing_project->creator->username . 
                ", it will be renamed to $new_name");
            $existing_project->rename($new_name);
            # TODO email user about name change?
        }
        else {
            my $name = $self->name;
            $self->delete;
            die "There is already a project name '$name', created by " . 
                $existing_project->creator->username . ". Select another name";
        }
    }

    # Make sure corresponding model group exists
    unless ($self->model_group) {
        my $model_group = Genome::ModelGroup->create(
            name => $self->name,
            user_name => $self->creator->email,
            uuid => $self->id,
        );
        unless ($model_group) {
            $self->delete;
            die "Failed to create corresponding model group for project!";
        }
        $self->status_message('Create corresponding model group: '.$model_group->id);
    }

    return 1;
}

sub rename_callback {
    my ($self, $property_name, $old_name, $new_name) = @_;
    my ($model_group) = Genome::ModelGroup->get(uuid => $self->id);
    if ($model_group) {
        $model_group->_rename($new_name);
    }
    return 1;
}

sub delete_callback {
    my $self = shift;
    my ($model_group) = Genome::ModelGroup->get(uuid => $self->id);
    return 1 if not $model_group;
    $model_group->_delete;
    return 1;
}

1;

