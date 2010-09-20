package Genome::Model::Build::Command;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
use Regexp::Common;

class Genome::Model::Build::Command {
    is => 'Command',
    doc => "work with model build",
    has => [
        filter => {
            is => 'Text',
            shell_args_position => 1,
            doc => 'Filter to get builds. Get by build id, last builds for model id/name, last builds for model group id/name or a list filter. Comma separate multiple values. If using a list filter (ie: status=Failed,run_by=$USER or model_id=$ID), this will get ALL builds that match.',
        },
    ],
};

#< Name >#
sub command_name {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name unless $class eq __PACKAGE__;
    return 'genome model build';
}

sub command_name_brief {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name_brief unless $class eq __PACKAGE__;
    return 'build';
}
#<>#

#< Builds From Filter >#
# build id => build
# by model id/name, group id/name: last build for each model
# by filter: all builds (status etc)
sub _builds_for_filter {
    my $self = shift;

    my $filter = $self->filter;
    if ( not defined $filter ) {
        Carp::confess('Get builds from command line called without filter');
    }

    my $wantlist = wantarray();
    if ( not defined $wantlist ) {
        Carp::confess('Build get from command line called in void context');
    }

    # If this is a filter, use default
    my @filter_parts = split(',', $filter);
    my $has_operator = grep { /[\=\~\<\>]/ } @filter_parts;
    if ( $has_operator > 0 ) { 
        if ( $has_operator == @filter_parts ) {
            $self->status_message("Gettign builds for filter: $filter");
            return Genome::Model::Build->from_cmdline($filter);
        }
        else {
            Carp::confess("Malformed filter ($filter) to get builds. Some filter parts have a key, operator and value, and some do not.");
        }
    }

    my %builds;
    FILTER_PART: for my $filter_part ( @filter_parts ) {
        # model name/ group name
        my @builds_for_filter_part;
        if ( $filter_part !~ /^$RE{num}{int}$/ ) {
            my %params;
            if ( $filter_part =~ /\%/ ) { # has wild card
                %params = ( 'name like' => $filter_part );
            }
            else {
                %params = ( name => $filter_part );
            }
            @builds_for_filter_part = $self->_get_last_builds_for_model_params(%params);
            if ( @builds_for_filter_part ) {
                $self->status_message("Got builds for model name: $filter_part");
                @builds{ map { $_->id } @builds_for_filter_part } = @builds_for_filter_part;
                next FILTER_PART;
            }
            @builds_for_filter_part = $self->_get_last_builds_for_model_group_params(name => $filter_part);
            if ( @builds_for_filter_part ) {
                $self->status_message("Got builds for model group name: $filter_part");
                @builds{ map { $_->id } @builds_for_filter_part } = @builds_for_filter_part;
            }
            next FILTER_PART;
        }
        
        # build id
        @builds_for_filter_part = Genome::Model::Build->get(id => $filter_part);
        if ( @builds_for_filter_part ) {
            $self->status_message("Got builds for id: $filter_part");
            @builds{ map { $_->id } @builds_for_filter_part } = @builds_for_filter_part;
            next FILTER_PART;
        }
        
        # model id
        @builds_for_filter_part = $self->_get_last_builds_for_model_params(id => $filter_part);
        if ( @builds_for_filter_part ) {
            $self->status_message("Got builds for model id: $filter_part");
            @builds{ map { $_->id } @builds_for_filter_part } = @builds_for_filter_part;
            next FILTER_PART;
        }

        # model group id
        @builds_for_filter_part = $self->_get_last_builds_for_model_group_params(id => $filter_part);
        if ( @builds_for_filter_part ) {
            $self->status_message("Got builds for model group id: $filter_part");
            @builds{ map { $_->id } @builds_for_filter_part } = @builds_for_filter_part;
            next FILTER_PART;
        }

        Carp::confess("Cannot get builds (via id, model id/name, group id/name) for filter part: $filter_part");
    }

    if ( not %builds ) {
        Carp::confess("No builds found for filter: $filter");
    }

    return map { $builds{$_} } sort { $a <=> $b } keys %builds;
}
#<>#

#< Get Last Builds for Model >#
sub _get_last_builds_for_model_group_params {
    my ($self, %params)  = @_;

    my @model_groups = Genome::ModelGroup->get(%params);
    return if not @model_groups;

    my @builds;
    for my $model_group ( @model_groups ) {
        my @models = $model_group->models;
        for my $model ( @models ) {
            my @model_builds = $model->builds;
            next if not @model_builds;
            push @builds, $model_builds[$#model_builds];
        }
    }

    return @builds;
}

sub _get_last_builds_for_model_params {
    my ($self, %params)  = @_;

    my @models = Genome::Model->get(%params);
    return if not @models;

    my @builds;
    for my $model ( @models ) {
        my @model_builds = $model->builds;
        next if not @model_builds;
        push @builds, $model_builds[$#model_builds];
    }

    return @builds;
}
#<>#

1;

