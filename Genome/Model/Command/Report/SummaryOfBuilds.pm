package Genome::Model::Command::Report::SummaryOfBuilds;

use strict;
use warnings;

use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';
use Regexp::Common;

class Genome::Model::Command::Report::SummaryOfBuilds {
    is => 'Genome::Report::GeneratorCommand',
    #is => 'Command',
    has_optional => [
        # How to restrict builds
        days => {
            is => 'Integer',
            doc => 'Restrict builds by date completed by going this many days back. Default is to not restrict builds based on date.',
        },
        processing_profile_id => {
            is => 'Text',
            doc => 'Get builds for models with this processing profile id.',
        },
        subject_ids => {
            is => 'Text',
            doc => 'Get builds for models by subject (dna) id(s). Separate by commas.',
        },
        subject_names => {
            is => 'Text',
            doc => 'Get builds for models by subject (dna) name(s). Separate by commas.',
        },
        type_name => {
            is => 'Text',
            doc => 'Get builds for models by type name.',
        },
        work_order_id => {
            is => 'Text',
            doc => 'Get builds for models associated with this work order id.',
        },
        most_recent_build_only => {
            is => 'Boolean',
            default_value => 0,
            doc => 'If a model has multiple builds completed, only show the most recent.',
        },
        # Show
        show => {
            is => 'Text',
            doc => 'Show only these properties for each build. To show defaults with other properties, use --show-additional.  Separate values by commas.',
        },
        show_additional => {
            is => 'Text',
            doc => 'Show these properties for each build, in addition to the defaults: build id, model id and . Separate values by commas.',
        },
        # As
        #as => { is => 'Text', doc => 'Use these headers for the properties to be shown for each build. Separate values by commas.', },
        # Private
        _description => {
            is => 'Text',
            doc => 'Report description.',
        },
        _number_of_builds_found => {
            is => 'Integer',
            doc => 'Number of builds found.',
        },
    ],
};

#< Help >#
sub help_brief {
    return 'Produce a report of completed builds';
}

sub help_detail {
    return <<EOS;
EOS
}

#< Execute >#
sub execute { 
    my $self = shift;

    # Build the sql query
    my $query = $self->_build_sql_query
        or return;
    #print "\n\n$query\n\n";
    
    # Execute the query - put in method to overload in test
    my $rows = $self->_selectall_arrayref($query)
        or return;
    return 1 unless @$rows; # FIXME ok, but handle better??

    # Most recent build? Remove the older ones 
    if ( $self->most_recent_build_only ) {
        my (%models_seen, @model_rows);
        for my $row ( @$rows ) { # order by most recent
            next if exists $models_seen{$row->[0]};
            push @model_rows, $row;
            $models_seen{$row->[0]} = $row;
        }
        $rows = \@model_rows;
    }

    # Get the properties and data for the report
    my ($properties, $data) = $self->_resolve_properties_and_data_to_show($rows)
        or return;

    $self->_number_of_builds_found( scalar(@$data) );
    print "Found ".scalar(@$data)." builds for ".$self->_description.".\n";

    # Generate report
    my $report = $self->_generate_report_and_execute_functions(
        name => 'Summary of Builds',
        description => 'Summary of builds for '.$self->_description,
        row_name => 'build',
        headers => $properties,
        rows => $data,
    ) or return;

    return $report;
}
#<>#

#< Builds >#
sub were_builds_found {
    return $_[0]->_number_of_builds_found;
}

sub _build_sql_query {
    my $self = shift;

    # determine/validate how to get builds, get the additional query parts,
    #  and set the description
    my $query_parts;
    if ( my $pp_id = $self->processing_profile_id ) {
        unless ( $pp_id =~ m#^$RE{num}{int}$# ) {
            $self->error_message("Processing profile id ($pp_id) is not an integer.");
            return;
        }
        my $pp = Genome::ProcessingProfile->get(id => $pp_id);
        unless ( $pp ) {
            $self->error_message("Can't get processing profile for id ($pp_id).");
            return;
        }
        $query_parts = $self->_get_query_parts_for_builds_by_processing_profile_id;
        $self->_description("processing profile id ($pp_id)");
    }
    elsif ( my $wo_id = $self->work_order_id ) {
        unless ( $wo_id =~ m#^$RE{num}{int}$# ) {
            $self->error_message("Work order id ($wo_id) is not an integer.");
            return;
        }
        my $wo = GSC::Setup::WorkOrder->get(id => $wo_id);
        unless ( $wo ) {
            $self->error_message("Can't get work order for id ($wo_id).");
            return;
        }
        $query_parts = $self->_get_query_parts_for_builds_by_work_order_id;
        $self->_description("work order id ($wo_id)");
    }
    elsif ( $self->subject_ids ) {
        $query_parts = $self->_get_query_parts_for_builds_by_model_property(
            'subject_id', $self->subject_ids
        )
            or return;
        $self->_description("subject id(s) (".$self->subject_ids.")");
    }
    elsif ( $self->subject_names ) { 
        $query_parts = $self->_get_query_parts_for_builds_by_model_property(
            'subject_name', $self->subject_names
        )
            or return;
        $self->_description("subject name(s) (".$self->subject_names.")");
    }
    elsif ( my $type_name = $self->type_name ){ 
        # TODO validate?
        $query_parts = $self->_get_query_parts_for_builds_by_type_name;
        $self->_description("type name ($type_name)");
    }
    else {
        $self->error_message("No method requested to get build events.");
        return;
    }

    # select
    my $query = <<SQL;
SELECT m.genome_model_id as model_id,
       b.build_id,
       e.event_status as build_status,
       to_char(e.date_completed, 'YYYY-MM-DD') as build_completed
SQL
    
    # joins to builds and events
    push @{$query_parts->{'join'}}, (
        'genome_model_build b on b.model_id = m.genome_model_id',
        'genome_model_event e on e.build_id = b.build_id',
    );
    # where for event type and completed date
    push @{$query_parts->{where}}, (
        "e.event_type = 'genome model build'",
        'e.date_completed is NOT NULL'
    );
    # add to query
    $query .= 'FROM '.join(", ", @{$query_parts->{from}});
    $query .= join('', map { "\nJOIN ".$_ } @{$query_parts->{'join'}});
    $query .= "\nWHERE ".join("\nAND ", @{$query_parts->{where}});

    # add time constraint
    if ( $self->days ) {
        $self->_validate_days
            or return;
        $query .=  "\nAND e.date_completed > sysdate - ".$self->days;
        $self->_description( $self->_description.'within the past '.$self->days.' days.');
    }
    $query .= "\nORDER BY e.date_completed DESC";

    return $query;
}

sub _selectall_arrayref { # put in sub so can overwrite in test
    return Genome::DataSource::GMSchema->get_default_dbh->selectall_arrayref($_[1]);
}

sub _get_query_parts_for_builds_by_type_name {
    return {
        from => [ 'processing_profile pp' ],
        'join' => [ 'genome_model m on m.processing_profile_id = pp.id' ],
        where => [ "pp.type_name = '".$_[0]->type_name."'" ],
    };
}

sub _get_query_parts_for_builds_by_processing_profile_id {
    return {
        from => [ 'genome_model m ' ],
        where => [ 'm.processing_profile_id = '. $_[0]->processing_profile_id ],
    };
}

sub _get_query_parts_for_builds_by_work_order_id {
    return {
        from => [ 'work_order_item@oltp w' ],
        'join' => [ 'genome_model m on m.subject_id = w.dna_id' ],
        where => [ 'w.setup_wo_id = '.$_[0]->work_order_id ],
    };
}

sub _get_query_parts_for_builds_by_model_property {
    my ($self, $property, $value_string) = @_;

    my @values = split(',', $value_string);
    unless ( @values ) {
        $self->error_message("Can't get values for $property from string ($value_string)");
        return;
    }

    return {
        from => [ 'genome_model m ' ],
        where => [ 'm.'.$property." in ('".join("', '", @values)."')" ],
    };
}

sub _validate_days {
    my $self = shift;

    # Validate days
    unless ( $self->days =~ /^$RE{num}{int}$/ ) {
        $self->error_message( sprintf('Days (%s) is not an integer.', $self->days) );
        return;
    }
    unless ( $self->days > 0 ) {
        $self->error_message( sprintf('Days (%s) is needs to be greater than 0.', $self->days) );
        return;
    }

    return 1;
}
#<>#

#< Properties to Show >#
sub _resolve_properties_and_data_to_show {
    my ($self, $retrieved_rows) = @_;

    if ( $self->show and $self->show_additional ) {
        $self->error_message("Indicated both show and show_additional. Please indicate only one of these options.");
        return;
    }

    my @default_properties = (qw/ 
        model_id build_id build_status date_completed 
        /);

    my (@row_properties, @build_properties);
    if ( $self->show ) { # show these
        for my $prop ( split(',', $self->show) ) {
            # See if a property is already retrieved
            if ( grep { $prop eq $_ } @default_properties ) {
                push @row_properties, $prop;
            }
            else {
                push @build_properties, $prop;
            }
        }
    }
    elsif ( $self->show_additional ) { # show defaults plus additional
        @row_properties = @default_properties;
        @build_properties = split(',', $self->show_additional);
    }
    else { # show defaults
        @row_properties = @default_properties;
    }
    
    my @data;
    for my $retrieved_row ( @$retrieved_rows ) {
        my @data_for_row;
        # Row props
        if ( @row_properties ) {
            my %retrieved_row;
            @retrieved_row{@default_properties} = @$retrieved_row;
            @data_for_row = map { $retrieved_row{$_} } @row_properties;
        }
        # Build Props
        if ( @build_properties ) {
            my $build_id = $retrieved_row->[1];
            my $build = Genome::Model::Build->get($build_id); 
            confess "Can't get build for id ($build_id)" unless $build; # should not happen!
            for my $prop ( @build_properties ) {
                my $value = $build->$prop;
                push @data_for_row, ( defined $value ? $value : '' );
            }
        }
        push @data, \@data_for_row;
    }

    return (
        [ map { $_ =~ s#\_#\-#g; $_ } @row_properties, @build_properties ], # properties
        \@data,
    );
}
#<>#

1;

#$HeadURL$
#$Id$
