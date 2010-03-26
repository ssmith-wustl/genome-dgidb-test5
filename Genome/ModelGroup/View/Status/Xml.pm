package Genome::ModelGroup::View::Status::Xml;

use strict;
use warnings;
use Genome;
use Data::Dumper;
use XML::LibXML;

class Genome::ModelGroup::View::Status::Xml {
    is => 'UR::Object::View::Default::Xml',
        has => [
            _doc    => {
                is_transient => 1,
                doc => 'the XML::LibXML document object used to build the content for this view'
            },
        ]
    };

# this is expected to return an XML string
# it has a "subject" property which is the individual we're viewing
sub _generate_content {
    my $self = shift;
    my $model_group = $self->subject;

    $DB::single = 1;

    my @models= $model_group->models;
    my $doc = XML::LibXML->createDocument();
    my $model_group_element = $doc->createElement('model-group');
    $doc->addChild($model_group_element);

    if ($model_group->convergence_model) {
        my $convergence_model = $model_group->convergence_model;
        my $convergence_element = $model_group_element->addChild( $doc->createElement('convergence-model') );
        $convergence_element->addChild( $doc->createAttribute('id', $convergence_model->id) );
        $convergence_element->addChild( $doc->createAttribute('name', $convergence_model->name) );

        if ($convergence_model->last_complete_build) {
            $convergence_element->addChild( $doc->createAttribute('last-complete-build-id', $convergence_model->last_complete_build->id) );
        }
    }

    #TODO This summary is probably obsoleted by Convergence models; eventually consolidate their views
    my $model_group_summary_element = $doc->createElement('summary');
    $model_group_summary_element->addChild(get_model_group_summary($model_group->id));
    $model_group_element->addChild($model_group_summary_element);

    my $model_group_name = $model_group->name;
    my $group_id = $model_group->id;

    my $model_list_element = get_model_list_element(\@models, { 'group-name' => $model_group_name, 'group-id' => $group_id } );
    $model_group_element->addChild($model_list_element);

    return $doc->toString(1);
}

sub get_model_group_summary {

    # returns an XML element containing model name / haploid coverage

    my ($model_group_id) = @_;

    my $map = sub {
        my ($model, $build) = @_;
        my $coverage = 0;
        my $model_id;

        if ($build) {
            $coverage = $build->get_metric('haploid_coverage') || 0;
        }

        my $node = XML::LibXML::Element->new('model');
        $node->setAttribute('model-id', $model->id());
        $node->setAttribute('model-name', $model->name());
        $node->setAttribute('haploid-coverage', $coverage);
        return $node;
    };

    my $reduce = sub {
        my (@coverage_nodes) = @_;

        my $model_group_coverage_node = XML::LibXML::Element->new('coverage');

        for my $cn (@coverage_nodes) {
            $model_group_coverage_node->addChild($cn->{'value'});
        }

        return $model_group_coverage_node;
    };

    my $mg = Genome::ModelGroup->get($model_group_id);
    my $frag = $mg->reduce_builds($reduce, $map);

    return $frag;
}

sub get_model_list_element {

    # used to be render_model_list
    my ($model_array_ref, $extra_attribute_ref) = @_;

    my @models = @{$model_array_ref};
    my %extra_attributes = %{$extra_attribute_ref};

    my $model_list_node = XML::LibXML::Element->new("model-list");
    my $time = UR::Time->now();

    $model_list_node->setAttribute("generated-at",$time);

    for my $attr (keys %extra_attributes) {
        $model_list_node->setAttribute($attr ,$extra_attributes{$attr});
    }

    my %model_latest_event;
    my %model_instrument_data;
    for my $m (@models) {
        my $latest_event_date;
        my $ar_events = 0;
        my $ar_succeeded_events = 0;

        my $modelnode = $model_list_node->addChild( XML::LibXML::Element->new("model") );
        $modelnode->setAttribute("model-id",$m->id);
        $modelnode->setAttribute("model-name",$m->name);
        $modelnode->setAttribute("user-name",$m->user_name);
        $modelnode->setAttribute("creation-date",$m->creation_date);
        $modelnode->setAttribute("sample-name",$m->subject_name);
        # $modelnode->setAttribute("subject-id",$m->subject_id);
        $modelnode->setAttribute("subject-name",$m->subject_name);
        $modelnode->setAttribute("subject-type",$m->subject_type);
        # $modelnode->setAttribute("subject-class-name",$m->subject_class_name);
        $modelnode->setAttribute("ar-events",$ar_events);
        $modelnode->setAttribute("ar-events-succeeded",$ar_succeeded_events);
        $modelnode->setAttribute("data-directory",$m->data_directory);
        if ($m->is_default) {
            $modelnode->setAttribute("is-default",$m->is_default);
        } else {
            $modelnode->setAttribute("is-default","0");
        }

        # add current builds node
        my $buildsnode = $modelnode->addChild(XML::LibXML::Element->new("current-builds"));
        for my $b ($m->builds) {
            my $buildnode = $buildsnode->addChild(XML::LibXML::Element->new("build"));
            # count total align-reads events and succeeded align-read events
            my $ar_events = 0;
            my $ar_events_succeeded = 0;
            for my $e ($b->events) {
                $DB::single = 1;

                if ($e->event_type =~ /align-reads/) {
                    $ar_events++;
                    if ($e->event_status eq 'Succeeded') {
                        $ar_events_succeeded++;
                    }
                }
            }

            $buildnode->setAttribute("build-id",$b->build_id);
            $buildnode->setAttribute("status",lc($b->build_status));
            $buildnode->setAttribute("ar-events",$ar_events);
            $buildnode->setAttribute("ar-events-succeeded",$ar_events_succeeded);
            $buildnode->setAttribute("date-scheduled",$b->date_scheduled);
            $buildnode->setAttribute("date-completed",$b->date_completed);

            # handle Failed and Running builds, which may or may not have date_completed values
            if ($b->date_scheduled && $b->date_completed) {
                $buildnode->setAttribute("elapsed-time", calculate_elapsed_time($b->date_scheduled,$b->date_completed) );
            } elsif ($b->build_status eq "Running") {
                $buildnode->setAttribute("elapsed-time", calculate_elapsed_time($b->date_scheduled,UR::Time->now) );
            } else {
                $buildnode->setAttribute("elapsed-time", "--" );
            }
            $buildsnode->addChild($buildnode);
        }

        $modelnode->addChild($buildsnode);
        $model_list_node->addChild($modelnode);

    }

    return $model_list_node;
}

sub calculate_elapsed_time {
    my $date_scheduled = shift;
    my $date_completed = shift;

    unless ($date_scheduled && $date_completed) {
        return 0;
    }

    my $diff;

    if ($date_completed) {
        $DB::single = 1;
        $diff = UR::Time->datetime_to_time($date_completed) - UR::Time->datetime_to_time($date_scheduled);
    } else {
        $DB::single = 1;
        $diff = time - UR::Time->datetime_to_time($date_scheduled);
    }

    # convert seconds to days, hours, minutes
    my $seconds = $diff;
    my $days = int($seconds/(24*60*60));
    $seconds -= $days*24*60*60;
    my $hours = int($seconds/(60*60));
    $seconds -= $hours*60*60;
    my $minutes = int($seconds/60);
    $seconds -= $minutes*60;
    my $formatted_time;
    if ($days) {
        $formatted_time = sprintf("%d:%02d:%02d:%02d",$days,$hours,$minutes,$seconds);
    } elsif ($hours) {
        $formatted_time = sprintf("%02d:%02d:%02d",$hours,$minutes,$seconds);
    } elsif ($minutes) {
        $formatted_time = sprintf("%02d:%02d",$minutes,$seconds);
    } else {
        $formatted_time = sprintf("%02d:%02d",$minutes,$seconds);
    }

    return $formatted_time;
}

1;

=pod

=head1 NAME

Genome::ModelGroup::View::Status::XML - status summary for a model group in XML format

=head1 SYNOPSIS

$i = Genome::ModelGroup->get(1234);
$v = Genome::ModelGroup::View::Status::Xml->create(subject => $i);
$xml = $v->content;

=head1 DESCRIPTION

This view renders the summary of an model group's status in XML format.

=cut

