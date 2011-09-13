package Genome::ModelGroup;

use strict;
use warnings;
use Genome;

class Genome::ModelGroup {
    table_name => 'MODEL_GROUP',
    id_by      => [ 
        id                  => { is => 'Number' }, 
    ],
    has => [
        name                => { is => 'Text' },
        user_name           => { is => 'Text', },
        uuid                => { is => 'Text', },
        model_bridges       => { is => 'Genome::ModelGroupBridge',
                                    reverse_as  => 'model_group',
                                    is_many     => 1
                                },
        models              => { is => 'Genome::Model',
                                    is_many => 1,
                                    is_mutable => 1,
                                    via     => 'model_bridges',
                                    to      => 'model'
                                },
        convergence_model   => { is => 'Genome::Model::Convergence',
                                    is_many     => 1, # We really should only have 1 here, however reverse_as requires this
                                    reverse_as  => 'group',
                                    doc         => 'The auto-generated Convergence Model summarizing knowledge about this model group',
                                    is_optional => 1, 
                                },
        user_name           => {is => 'Text',
                                is_optional => 1
                               },
        uuid                => {is => 'Text',
                                is_optional => 1
                               },
        project             => { 
            is => 'Genome::Project',
            is_optional => 1,
            id_by => 'uuid',
        },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub __display_name__ {
    my $self = shift;
    my @models = $self->models();
    return join(' ' ,$self->name, '('. scalar(@models), 'models)');
}

sub create {
    my $class = shift;

    # Strip out convergence model params
    my ($bx,%params) = $class->define_boolexpr(@_);
    my %convergence_model_params = ();
    if(exists $params{convergence_model_params}) {
        %convergence_model_params = %{ delete $params{convergence_model_params} };
    } 

    # Create project
    my $name = $bx->value_for('name');
    my $project = Genome::Project->create(
        name => $name,
    );
    if ( not $project ) {
        __PACKAGE__->error_message('Failed to create project to match model group.');
        return;
    }

    # Create, set some props from the project
    my $self = $class->SUPER::create($bx);
    if ( not $self ) {
        $project->delete;
        return;
    }
    $self->name( $project->name ) if $project->name ne $self->name;
    $self->uuid( $project->id );
    $self->user_name( $project->creator->email );

    # Convergence model
    my $define_command = Genome::Model::Command::Define::Convergence->create(
        %convergence_model_params,
        model_group_id => $self->id
    );
    unless ($define_command->execute == 1) {
        $self->error_message("Failed to create convergence model associated with this model group");
        $self->delete;
        return;
    }
    my $convergence_model = Genome::Model->get( $define_command->result_model_id );
    if ( not $convergence_model ) {
        $self->error_message('Failed to find convergence model with id from define command: '.$define_command->result_model_id);
        return;
    }

    # Add models to project
    for my $model ( $self->models ) {
        $project->add_model($model);
    }

    return $self;
}

sub rename {
    my ($self, $new_name) = @_;

    if ( not $new_name ) {
        $self->error_message('No new name given to rename model group');
        return;
    }

    my @model_groups = Genome::ModelGroup->get(name => $new_name);
    if ( @model_groups ) {
        $self->error_message("Failed to rename model group (".$self->id.") from ".$self->name." to $new_name because one the nwe name already exists.");
        return;
    }

    if ( my $project = $self->project ) { # delegate to project
        return $project->rename($new_name);
    }
    else {
        return $self->_rename($new_name);
    }
}

sub _rename {
    my ($self, $new_name) = @_;

    if ( not $new_name ) {
        Carp::confess('No new name given to rename model group');
    }

    my $old_name = $self->name;
    $self->name($new_name);
    $self->status_message("Renamed model group from '$old_name' to '$new_name'");

    if ( my $convergence_model = $self->convergence_model ) {
        my $old_model_name = $convergence_model->name;
        $convergence_model->name( $self->name . '_convergence' );
        $convergence_model->status_message("Renamed convergence model from '$old_model_name' to '".$convergence_model->name."'.");
    }

    return 1;
}

sub subjects {
    my $self = shift;
    my @models = $self->models;
    my @subjects = Genome::Subject->get([ map { $_->subject_id } @models ]);
    return @subjects;
}

sub assign_models {
    my ($self, @models) = @_;

    if ( not @models ) {
        $self->error_message('No models given to assign to group');
        return;
    }

    my $added = 0;
        my $project = $self->project;
        my %existing_models = map { $_->id => $_ } $self->models;
        for my $m (@models) {
            if ( exists $existing_models{ $m->id } ) {
                $self->status_message('Skipping model '.$m->__display_name__.', it is already assigned...');
            next;
        }
        my $bridge = Genome::ModelGroupBridge->create(
            model_group_id => $self->id,
            model_id       => $m->genome_model_id,
        );
        $project->add_model($m) if $project;
        $existing_models{$m->id} = $m->id;
        $added++;
    }

    my $attempted = scalar @models;
    my $skipped = $attempted - $added;
    $self->status_message("Added $added models to group: ".$self->__display_name__.". Skipped $skipped of $attempted models because they were already assigned.");

    if ( $added ) {
        $self->schedule_convergence_rebuild;
    }
    
    return 1;
}

sub unassign_models {

    my ($self, @models) = @_;

    if ( not @models ) {
        $self->error_message('No models given to unassign from group');
        return;
    }

    my $removed = 0;
    my $project = $self->project;
    for my $m (@models) {

        my $bridge = Genome::ModelGroupBridge->get(
            model_group_id => $self->id,
            model_id       => $m->genome_model_id,
        );
        
        unless($bridge){
            $self->warning_message("Model " . $m->id . " not found in group");
            next;
        }
        
        $bridge->delete();
        $project->remove_model($m) if $project;
        $removed++;
    }

    if ( $removed ) {
        $self->schedule_convergence_rebuild;
    }

    return 1;
}

sub schedule_convergence_rebuild {
    my $self = shift;
    
    if (defined $self->convergence_model) {
        $self->status_message("Trying rebuild of associated convergence model.");
        unless($self->convergence_model->schedule_rebuild) {
            $self->error_message($self->convergence_model->error_message);
            die $self->error_message;
        }
    }
    
    return 1;
}

sub map_builds {

    my ($self, $func) = @_;
    my @result;

    my @models = $self->models();

    for my $model (@models) {

        my $build = $model->last_complete_build();
        my $value = $func->($model, $build); # even if $build is undef
    
        push @result,
            {
            'model'    => $model,
            'model_id' => $model->id,
            'build'    => $build,
            'value'    => $value
            };
    }

    return @result;
}

sub reduce_builds {
    # apply $reduce function on results of $map or list 
    # of builds for this model group
    
    my ($self, $reduce, $map) = @_;
    my @b;

    if ($map) {
        @b = $self->map_builds($map);
    } else {
        @b = $self->builds();
    }

    my $result = $reduce->(@b);
    return $result;
}

sub builds {
    my ($self) = @_;
    my @models = $self->models();
    my @builds;

    for my $model (@models) {
        my $build = $model->last_complete_build();
        next if !$build;
        push @builds, $build;
    }

    return @builds;
}

sub delete {
    my $self = shift;

    # unassign existing models
    my @models = $self->models;
    if (@models) {
        $self->status_message("Unassigning " . @models . " models from " . $self->__display_name__ . ".");
        $self->unassign_models(@models);
    }

    # delete convergence model (and indirectly its builds)
    my $convergence_model = $self->convergence_model;
    if ($convergence_model) {
        my $deleted_model = eval {
            $convergence_model->delete;
        };
        if ($deleted_model) {
            $self->status_message("Removed convergence model.");
        }
        else {
            $self->error_message("Failed to remove convergence model (" . $convergence_model->__display_name__ . "), please investigate and remove manually.");
        }
    }

    if ( my $project = $self->project ) {
        $self->status_message('Deleting associated project: '.$project->id);
        $project->delete;
    }

    # delete self
    return $self->SUPER::delete;
}

# Attempts to infer what the overarching subject of the group is. If no pattern is found, assumes unknown taxon.
# The most specific this can get is the population group level.
sub infer_group_subject {
    my $self = shift;

    my @individuals;
    my @taxons;
    my $use_taxon = 0;
    my $use_unknown_taxon = 0;

    for my $model ($self->models) {
        my $subject = $model->subject;
        next unless $subject;

        if ($subject->isa('Genome::Sample')) {
            my $indiv = $subject->patient;
            unless ($indiv) {
                $use_taxon = 1;
                next;
            }
            push @individuals, $indiv;
        }
        elsif ($subject->isa('Genome::PopulationGroup')) {
            push @individuals, $subject->members;
        }
        elsif ($subject->isa('Genome::Taxon')) {
            $use_taxon = 1;
            push @taxons, $subject;
        }
        elsif ($subject->isa('Genome::Individual')) {
            push @individuals, $subject;
        }
        else {
            $use_unknown_taxon = 1;
            last;
        }
    }

    my $group_subject;
    if (not $use_taxon and not $use_unknown_taxon) {
        $group_subject = Genome::PopulationGroup->get(name => $self->default_population_group_name);
        if ($group_subject) {
            $group_subject->change_group_membership(@individuals);
        }
        else {
            $group_subject = Genome::PopulationGroup->create(
                name => $self->default_population_group_name,
                members => \@individuals,
            );
            $use_taxon = 1 unless $group_subject;
        }
    }

    if (not $group_subject and $use_taxon and not $use_unknown_taxon) {
        push @taxons, map { $_->taxon } @individuals;
        my %taxons;
        map { $taxons{$_->id}++ } @taxons;
        if ((keys %taxons) == 1) {
            $group_subject = $taxons[0];
        }
    }

    if (not $group_subject) {
        $group_subject = Genome::Taxon->get(name => 'unknown');
        unless ($group_subject) {
            Carp::confess 'Could not infer subject for model group ' . $self->id . ' and could not find unknown taxon!';
        }
    }

    return $group_subject;
}
    
sub default_population_group_name {
    my $self = shift;
    return 'population group for model group ' . $self->name;
}

sub tags_for_model {

    my ($self, $model_id) = @_;

    die 'Error: cant get tags- no model_id provided' if !$model_id;

    my $bridge = Genome::ModelGroupBridge->get(
            model_group_id => $self->id,
            model_id => $model_id
    );    

    my @notes = Genome::MiscNote->get(
            subject_id  => $bridge->id()
    );

    my %tags = map { $_->header_text() => $_->body_text() } @notes;

    return \%tags;
}

1;



