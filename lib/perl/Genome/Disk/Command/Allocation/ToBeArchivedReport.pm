package Genome::Disk::Command::Allocation::ToBeArchivedReport;

use strict;
use warnings;
use Genome;

class Genome::Disk::Command::Allocation::ToBeArchivedReport {
    is => 'Command::V2',
    has => [
        allocations => {
            is => 'Genome::Disk::Allocation',
            is_many => 1,
            shell_args_position => 1,
            doc => 'allocations that are to be archived',
        },
    ],
};

sub help_detail { 
    return 'displays information about allocations that will soon be archived';
}
sub help_brief { return help_detail() };
sub help_synopsis { return help_detail() . "\n" };

sub output_fields {
    return qw/
        allocation_id
        absolute_path
        kilobytes_requested
        model_ids
        model_names
        model_subjects
        model_groups
        group_owners
        last_complete_build_timestamps
    /;
}
        
sub execute {
    my $self = shift;
    
    print join(',', $self->output_fields) . "\n";

    my @errors;
    for my $allocation ($self->allocations) {
        eval { 
            my %fields;
            $fields{allocation_id} = $allocation->id;
            $fields{absolute_path} = $allocation->absolute_path;
            $fields{kilobytes_requested} = $allocation->kilobytes_requested;

            my @models = $self->resolve_models_from_allocation($allocation);
            $self->_print_line(%fields) unless @models;

            $fields{model_ids} = join('|', map { $_->id } @models);
            $fields{model_names} = join('|', map { $_->name } @models);
            $fields{model_subjects} = join('|', map { $_->subject->name } @models);

            my @groups = grep { defined $_ } map { $_->model_groups } @models;
            if (@groups) {
                $fields{model_groups} = join('|', map { $_->name } @groups);
                $fields{group_owners} = join('|', map { $_->user_name } @groups);
            }

            my @builds = grep { defined $_ } map { $_->last_complete_build } @models;
            if (@builds) {
                $fields{last_complete_build_timestamps} = join('|', map { $_->date_completed } @builds);
            }

            $self->_print_line(%fields);
        };

        my $error = $@;
        if ($error) {
            push @errors, $error;
        }
    }

    $self->_print_error_summary(@errors);
    return 1;
}

sub _print_line {
    my $self = shift;
    my %fields = @_;
    my @values = map { $fields{$_} || '-' } $self->output_fields;
    print join(',', @values) . "\n";
}

sub _print_error_summary {
    my $self = shift;
    my @errors = @_;
    return unless @errors;

    print "The following errors occurred during execution:\n";
    my $num = 0;
    for my $error (@errors) {
        chomp $error;
        print ++$num . " => " . $error . "\n";
    }
    return 1;
}

sub resolve_models_from_allocation {
    my ($self, $allocation) = @_;

    my $class = $allocation->owner_class_name;
    eval { require $class };
    my $error = $@;
    if (defined $error and $error =~ /Can't locate $class/) {
        return;
    }
    elsif (defined $error) { # Rethrow
        die "Unexpected error while attempting to load class $class: $error";
    }

    return unless $allocation->owner;

    my %supported_owner_classes = $self->supported_owner_classes;
    my @matches = grep { $allocation->owner_class_name->isa($_) } sort keys %supported_owner_classes;

    my @models;
    for my $match (@matches) {
        my $method_name = $supported_owner_classes{$match};
        next unless $self->can($method_name);
        push @models, $self->$method_name($allocation->owner);
    }
    return @models;
}

sub supported_owner_classes {
    return (
        'Genome::SoftwareResult' => '_resolve_models_from_software_result',
        'Genome::Model::Build' => '_resolve_models_from_build',
        'Genome::Model::Event' => '_resolve_models_from_event',
        'Genome::InstrumentData' => '_resolve_models_from_instrument_data',
    );
}

sub _resolve_models_from_software_result {
    my ($self, $result) = @_;

    my @users = $result->users;
    return unless @users;

    my @build_users = grep { $_->user_class_name->isa('Genome::Model::Build') } @users;
    return unless @build_users;

    my @builds = map { $_->user } @build_users;
    return unless @builds;

    my @models = map { $_->model } @builds;
    return @models;
}

sub _resolve_models_from_build {
    my ($self, $build) = @_;
    return $build->model;
}

sub _resolve_models_from_event {
    my ($self, $event) = @_;
    return $event->model;
}

sub _resolve_models_from_instrument_data {
    my ($self, $instrument_data) = @_;
    my @inputs = Genome::Model::Input->get(name => 'instrument_data', value_id => $instrument_data->id);
    return map { $_->model } @inputs;
}

1;

