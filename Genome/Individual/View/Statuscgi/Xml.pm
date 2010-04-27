package Genome::Individual::View::Statuscgi::Xml;

use strict;
use warnings;
use Genome;
use Data::Dumper;
use XML::LibXML;

class Genome::Individual::View::Statuscgi::Xml {
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

    # build document XML
    my $doc = XML::LibXML->createDocument();
    my $individual_node = $doc->createElement("individual");

    my $individual = $self->subject;

    # individual info
    my $individual_info_node = $individual_node->addChild( $doc->createElement("individual-info") );
    $individual_info_node->addChild( $doc->createAttribute("name",$individual->common_name) );
    $individual_info_node->addChild( $doc->createAttribute("gender",$individual->gender) );

    # individual models

    my @samples = Genome::Sample->get(source_id=>$individual->id);
    my @models;

    for my $sample (@samples) {
        my $common_name= $sample->common_name || "No Common Name";
        my $extraction_desc = $sample->extraction_desc || "No Extraction Info";
        my $tissue_desc = $sample->tissue_desc || "No Tissue Info";

        my $sample_description = sprintf("%s | %s | %s", $common_name, $extraction_desc, $tissue_desc);
        #print $sample_description, "\n";

        push(@models, $sample->models);
        # @models = $sample->models;

        #for (@models) {
        #    printf("\t%s %s\n", $_->id, $_->name);
        #}
    }

    $DB::single = 1;

    my $model_list_node = $individual_node->addChild( $doc->createElement("model-list") );
    my $time = UR::Time->now();

    $model_list_node->addChild( $doc->createAttribute("generated-at",$time) );
    # $model_list_node->addChild( $doc->createAttribute("model-search-string",$model_search_string) );

    my %model_latest_event;
    my %model_instrument_data;
    for my $m (@models) {
        my $latest_event_date;
        my $ar_events = 0;
        my $ar_succeeded_events = 0;

        $DB::single = 1;

        my $modelnode = $model_list_node->addChild( $doc->createElement("model") );
        $modelnode->addChild( $doc->createAttribute("model-id",$m->id) );
        $modelnode->addChild( $doc->createAttribute("model-name",$m->name) );
        $modelnode->addChild( $doc->createAttribute("user-name",$m->user_name) );
        $modelnode->addChild( $doc->createAttribute("creation-date",$m->creation_date) );
        $modelnode->addChild( $doc->createAttribute("sample-name",$m->subject_name) );
        # $modelnode->addChild( $doc->createAttribute("subject-id",$m->subject_id) );
        $modelnode->addChild( $doc->createAttribute("subject-name",$m->subject_name) );
        $modelnode->addChild( $doc->createAttribute("subject-type",$m->subject_type) );
        # $modelnode->addChild( $doc->createAttribute("subject-class-name",$m->subject_class_name) );
        $modelnode->addChild( $doc->createAttribute("ar-events",$ar_events) );
        $modelnode->addChild( $doc->createAttribute("ar-events-succeeded",$ar_succeeded_events) );
        $modelnode->addChild( $doc->createAttribute("data-directory",$m->data_directory) );
        if ($m->is_default) {
            $modelnode->addChild( $doc->createAttribute("is-default",$m->is_default) );
        } else {
            $modelnode->addChild( $doc->createAttribute("is-default","0") );
        }

        # add current builds node
        my $buildsnode = $modelnode->addChild($doc->createElement("current-builds"));
        for my $b ($m->builds) {
            my $buildnode = $buildsnode->addChild($doc->createElement("build"));
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

            $buildnode->addChild( $doc->createAttribute("build-id",$b->build_id) );
            $buildnode->addChild( $doc->createAttribute("status",lc($b->build_status)) );
            $buildnode->addChild( $doc->createAttribute("ar-events",$ar_events) );
            $buildnode->addChild( $doc->createAttribute("ar-events-succeeded",$ar_events_succeeded) );
            $buildnode->addChild( $doc->createAttribute("date-scheduled",$b->date_scheduled) );
            $buildnode->addChild( $doc->createAttribute("date-completed",$b->date_completed) );

            # handle Failed and Running builds, which may or may not have date_completed values
            if ($b->date_scheduled && $b->date_completed) {
                $buildnode->addChild( $doc->createAttribute("elapsed-time", calculate_elapsed_time($b->date_scheduled,$b->date_completed) ));
            } elsif ($b->build_status eq "Running") {
                $buildnode->addChild( $doc->createAttribute("elapsed-time", calculate_elapsed_time($b->date_scheduled,UR::Time->now) ));
            } else {
                $buildnode->addChild( $doc->createAttribute("elapsed-time", "--" ));
            }
            $buildsnode->addChild($buildnode);
        }

        $modelnode->addChild($buildsnode);
        $model_list_node->addChild($modelnode);

    }

    $doc->setDocumentElement($individual_node);
    return $doc->toString(1);
}

sub calculate_elapsed_time {
    my $self = shift;
    my $date_scheduled = shift;
    my $date_completed = shift;

    my $diff;

    if ($date_completed) {
        $diff = UR::Time->datetime_to_time($date_completed) - UR::Time->datetime_to_time($date_scheduled);
    } elsif ($date_scheduled) {
        $diff = time - UR::Time->datetime_to_time( $date_scheduled);
    } else {
		$diff = -1;
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

Genome::Individual::View::Status::XML - status summary for an individual in XML format

=head1 SYNOPSIS

$i = Genome::Individual->get(1234);
$v = Genome::Individual::View::Status::Xml->create(subject => $i);
$xml = $v->content;

=head1 DESCRIPTION

This view renders the summary of an individual's status in XML format.

=cut

