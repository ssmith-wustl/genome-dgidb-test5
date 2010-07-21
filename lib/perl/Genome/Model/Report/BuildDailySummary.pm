package Genome::Model::Report::BuildDailySummary;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
use Regexp::Common;

class Genome::Model::Report::BuildDailySummary {
    is => 'Genome::Report::Generator',
    has => [
    name => {
        default_value => 'Build Daily Summary',
        is_constant => 1,
    },
    description => {
        default_value => 'Builds Completed within the Last Day',
        is_constant => 1,
    },
    _requested_method_get_builds => {
        is => 'Text',
        doc => 'Method to get the builds for the report',
    },
    _rows => {
        is => 'ARRAY',
        doc => 'Array of rows qith build event info.',
    },
    _builds => {
        is => 'ARRAY',
        doc => 'Array of completed builds.',
    },
    ],
    has_optional => [
    type_name => {
        is => 'Text',
        doc => 'Get builds of the type name',
    },
    processing_profile_id => {
        is => 'Text',
        doc => 'Get builds with this specific processing profile id',
    },
    show_most_recent_build_only => {
        is => 'Boolean',
        default_value => 0,
        doc => 'If a model has multiple builds completed, only show the most recent.',
    },
    ],
};

sub create { 
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    if ( my $pp_id = $self->processing_profile_id ) {
        unless ( $pp_id =~ m#^$RE{num}{int}$# ) {
            $self->error_message("Processing profile id ($pp_id) is not an integer.");
            $self->delete;
            return;
        }
        my $pp = Genome::ProcessingProfile->get(id => $pp_id);
        unless ( $pp ) {
            $self->error_message("Can't get processing profile for id ($pp_id).");
            $self->delete;
            return;
        }
        $self->_requested_method_get_builds('processing_profile_id');
        $self->type_name($pp->type_name);
    }
    elsif ( my $type_name = $self->type_name ){ 
        # TODO validate?
        $self->_requested_method_get_builds('type_name');
    }
    else {
        $self->error_message("No method requested to get build events.");
        $self->delete;
        return;
    }

    #my $validation_method = '_validate_';
    #unless ( $self->$validation_method ) {
    #    $self->error_message("Can't validate $requested_methods[0]. See error above.");
    #    $self->delete;
    ##    return;
    #}

    return $self;
}

sub _add_to_report_xml {
    my $self = shift;

    $self->_load_yesterdays_completed_builds
        or return;

    $self->_add_dataset(
        name => 'builds',
        row_name => 'build',
        headers => [qw/ 
        model-id model-name subject-name run-count 
        build-id data-directory build-status date-completed
        /],
        rows => $self->_rows,
    );

    return 1;
}

#< Events >#
sub were_events_found {
    return $_[0]->_rows ? 1 : 0;
}

sub _load_yesterdays_completed_builds {
    my $self = shift;

    unless ( $self->_requested_method_get_builds ) {
        $self->error_message("No method requested to get builds.");
        return;
    }

    my $method = '_construct_query_part_for_'.$self->_requested_method_get_builds;
    my $processing_profile_sql = $self->$method;
    
    my $query = <<SQL;
SELECT m.genome_model_id as model_id,
       m.name as model_name,
       m.subject_name as subject_name,
       ida.run_count as run_count,
       b.build_id,
       b.data_directory,
       e.event_status as build_status,
       to_char(e.date_completed, 'YYYY-MM-DD') as build_completed
  FROM genome_model m,
       genome_model_build b,
       genome_model_event e,
       (
          SELECT model_id,
                 count(*) as run_count
            FROM model_instrument_data_assgnmnt
        GROUP BY model_id
       ) ida,
       processing_profile pp
 WHERE $processing_profile_sql AND
       m.processing_profile_id = pp.id AND
       e.event_type = 'genome model build' AND
       m.genome_model_id = b.model_id AND
       b.build_id = e.build_id AND
       m.genome_model_id = ida.model_id AND
       e.date_completed > sysdate - 1
ORDER BY e.date_completed DESC
SQL


    my $rows = $self->_selectall_arrayref($query);
    unless ( @$rows ) {
        $self->status_message("No builds found that completed yesterday.");
        return;
    }

    if ( $self->show_most_recent_build_only ) {
        my (%models_seen, @model_rows);
        for my $row ( @$rows ) { # order by most recent
            next if exists $models_seen{$row->[0]};
            push @model_rows, $row;
            $models_seen{$row->[0]} = $row;
        }
        $rows = \@model_rows;
    }
    
    return $self->_rows($rows);
}

sub _selectall_arrayref { # put in sub so can overwrite in test
    return Genome::DataSource::GMSchema->get_default_dbh->selectall_arrayref($_[1]);
}

sub _construct_query_part_for_processing_profile_id {
    return 'm.processing_profile_id = '.$_[0]->processing_profile_id;
}

sub _construct_query_part_for_type_name {
    return "pp.type_name = '".$_[0]->type_name."'";
}

#< Additional Data Based on Type Name >#
sub _additional_data_for_amplicon_assembly {
    #TODO
}

1;

#$HeadURL$
#$Id$
