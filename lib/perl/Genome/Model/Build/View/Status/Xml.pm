#:boberkfe this looks like a good place to use memcache to cache up some build status.
#:boberkfe when build events update, stuff their status into memcache.  gathering info otherwise
#:boberkfe can get reaaaaal slow.

package Genome::Model::Build::View::Status::Xml;

use strict;
use warnings;
use Genome;
use Data::Dumper;
use XML::LibXML;
use XML::LibXSLT;

class Genome::Model::Build::View::Status::Xml {
    is => 'Genome::View::Status::Xml',
    has => [
        _doc    => {
            is_transient => 1,
            doc => 'the XML::LibXML document object used to build the content for this view'
        },
    ],
    has_optional => [
        instance_id => {
            is => 'String',
            doc => 'Optional id of the workflow operation instance to use.'
        },
        instance => {
            is => 'Workflow::Operation::Instance',
            id_by => 'instance_id',
        },
        section => {
            is => 'String',
            doc => "NOT IMPLEMENTED YET.  The sub-section of the document to return.  Options are 'all', 'events', etc.",
        },
        use_lsf_file => {
            is => 'Integer',
            default_value => 0,
            doc => "A flag which lets the user retrieve LSF status from a temporary file rather than using a bjobs command to retrieve the values.",
        },
        _job_to_status => {
            is => 'HASH',
            doc => "The XML generated by the status call.",
        },
    ],
};

# this is expected to return an XML string
# it has a "subject" property which is the model we're viewing
sub _generate_content {
    my $self = shift;

    #create the XML doc and add it to the object
    my $doc = XML::LibXML->createDocument();
    $self->_doc($doc);

    my $subject = $self->subject;
    return unless $subject;

    my $return_value = 1;

    #create _job_to_status hash
    if ($self->use_lsf_file) {
        my $job_status_hash = $self->load_lsf_job_status();
        $self->_job_to_status($job_status_hash);
    }

    #create the xml nodes and fill them up with data
    #root node
    my $build_status_node = $doc->createElement("build-status");
    my $time = UR::Time->now();
    $build_status_node->addChild( $doc->createAttribute("generated-at",$time) );

    #build node
    my $buildnode = $self->get_build_node();
    $build_status_node->addChild($buildnode);

    ## find the latest workflow for this build
    unless ($self->instance) {
        $self->instance($subject->newest_workflow_instance);
    }

    if ($self->instance) {
=pod
        # silly UR tricks to get everything i'm interested in loaded into the cache in 2 queries

        #        my @exec_ids = map {
        #            $_->current_execution_id
        #        } (Workflow::Operation::Instance->get(
        #            id => $self->instance->id,
        #            -recurse => ['parent_instance_id','instance_id']
        #        ));

        my @ids = map {
            $_->id
        } (Workflow::Operation::Instance->get(
            sql => 'select workflow_instance.workflow_instance_id
                      from workflow_instance
                     start with workflow_instance.parent_instance_id = ' . $self->instance->id . '
                     connect by workflow_instance.parent_instance_id = prior workflow_instance.workflow_instance_id'
                 ));

        my @ex = Workflow::Operation::InstanceExecution->get(
            instance_id => { operator => '[]', value=>\@ids }
        );
=cut

        $buildnode->addChild( $self->get_workflow_node );
    }

    #processing profile
    $buildnode->addChild ( $self->get_processing_profile_node() );

    #TODO:  add method to build for logs, reports
    #$buildnode->addChild ( $self->tnode("logs","") );
    $buildnode->addChild ( $self->get_reports_node );

    #set the build status node to be the root
    $doc->setDocumentElement($build_status_node);

    #generate the XML string
    return $doc->toString(1);

}

=cut
    #print to the screen if desired
    if ( $self->display_output ) {
        if ( lc $self->output_format eq 'html' ) {
            print $self->to_html($self->_xml);
        } else {
            print $self->_xml;
        }
    }

    return $return_value;
sub xml {
    my $self = shift;
    return $self->_xml;
}

=cut

sub get_root_node {
    my $self = shift;
    return $self->_doc;
}


sub get_reports_node {
    my $self = shift;
    my $build = $self->subject;
    my $report_dir = $build->resolve_reports_directory;
    my $reports_node = $self->anode("reports", "directory", $report_dir);
    my @report_list = $build->reports;
    for my $each_report (@report_list) {
        my $report_node = $self->anode("report","name", $each_report->name );
        $self->add_attribute($report_node, "subdirectory", $each_report->name_to_subdirectory($each_report->name) );
        $reports_node->addChild($report_node);
    }

    return $reports_node;
}

sub get_events_node {
    my $self = shift;
    my $doc = $self->_doc;

    my $events_list = $doc->createElement("events");
    my @events = $self->subject->events;

    for my $event (@events) {
        my $event_node = $self->get_event_node($event);
        $events_list->addChild($event_node);
    }

    return $events_list;

}

sub get_build_node {

    my $self = shift;
    my $doc = $self->_doc;

    my $buildnode = $doc->createElement("build");

    my $build = $self->subject;
    my $model = $build->model;
    my $subject = $model->subject;

    my $source;
    if ($subject && $subject->can("source")) {
        $source = $subject->source;
    }

    my $disk_allocation = $build->disk_allocation;
    my $kb_requested = ($disk_allocation ? $disk_allocation->kilobytes_requested : 0);

    # grab any build-event allocations as well to include into total allocation held
    my @events = $build->events;
    my @event_allocations = Genome::Disk::Allocation->get(owner_id=>[map {$_->id} @events]);

    for (@event_allocations) {
        $kb_requested += $_->kilobytes_requested;
    }

    if (not defined $disk_allocation) {
        $kb_requested .= ' (incomplete)';
    }


    $buildnode->addChild( $doc->createAttribute("model-name",$model->name) );
    $buildnode->addChild( $doc->createAttribute("model-id",$model->id) );
    if ($source) {
        $buildnode->addChild(
            $doc->createAttribute("common-name", $source->common_name || 'UNSPECIFIED!')
        );
    }
    $buildnode->addChild( $doc->createAttribute("build-id",$build->id) );
    $buildnode->addChild( $doc->createAttribute("status",$build->build_status) );

    $buildnode->addChild( $doc->createAttribute("metric-count", ($build->build_status == 'Succeeded' ? scalar @{[ $build->metrics ]} : 0) ) );

    if ($kb_requested) {
        $buildnode->addChild( $doc->createAttribute("kilobytes-requested",$kb_requested) );
    }
    $buildnode->addChild( $doc->createAttribute("data-directory",$build->data_directory) );
    $buildnode->addChild( $doc->createAttribute("lsf-job-id", $build->build_event->lsf_job_id));
    
    $buildnode->addChild( $doc->createAttribute("software-revision", $build->software_revision) );

    my $event = $build->build_event;

    my $out_log_file = $event->resolve_log_directory . "/" . $event->id . ".out";
    my $err_log_file = $event->resolve_log_directory . "/" . $event->id . ".err";

    if (-e $out_log_file) {
        $buildnode->addChild( $doc->createAttribute("output-log",$out_log_file));
    }
    if (-e $err_log_file) {
        $buildnode->addChild( $doc->createAttribute("error-log",$err_log_file));
    }
    
    $buildnode->addChild( $doc->createAttribute("summary-report", $self->get_summary_report_location) );

    $buildnode->addChild($self->get_model_node);
    
    $buildnode->addChild($self->get_inputs_node);
    $buildnode->addChild($self->get_links_node);

    return $buildnode;
}

#Separate method to make it easy to override in subclasses
sub get_summary_report_location {
    my $self = shift;
    my $build = $self->subject;
    
    #A default value equivalent to what was previously hardcoded in the XSL.
    return $build->reports_directory . '/Summary/report.html';
}

sub get_model_node {
    my $self = shift;
    my $doc = $self->_doc;

    my $modelnode = $doc->createElement("model");

    my $model = $self->subject->model;

    #For generating links
    $modelnode->addChild( $doc->createAttribute("id", $model->id));
    $modelnode->addChild( $doc->createAttribute("type", $model->class));
    my $namenode = $modelnode->addChild( $self->anode('aspect', 'name', 'name'));
    $namenode->addChild( $self->tnode('value', $model->name));

    return $modelnode;
}

sub get_workflow_node {
    my $self = shift;
    my $doc = $self->_doc;

    my $workflownode = $doc->createElement("workflow");

    $workflownode->addChild( $doc->createAttribute("instance-id", $self->instance->id));
    $workflownode->addChild( $doc->createAttribute("instance-status", $self->instance->status));

    #For generating links
    $workflownode->addChild( $doc->createAttribute("id", $self->instance->id));
    $workflownode->addChild( $doc->createAttribute("type", $self->instance->class));

    return $workflownode;
}

#Note:  Since the Web server cannot execute bjob commands, use the cron'd results from the tmp file
sub X_load_lsf_job_status {
    my $self = shift;

    my %job_to_status;
    my $lsf_file = '/gsc/var/cache/testsuite/lsf-tmp/bjob_query_result.txt';
    my @bjobs_lines = IO::File->new($lsf_file)->getlines;
    shift(@bjobs_lines);
    for my $bjob_line (@bjobs_lines) {
        my @job = split(/\s+/,$bjob_line);
        $job_to_status{$job[0]} = $job[2];
    }
    return \%job_to_status;
}

our $JOB_TO_STATUS;
sub load_lsf_job_status {
    my $self = shift;

    # NOTE: This caches the lsf job data for as long as the process stays alive.
    # For now, this thing is run from a regular CGI script, so the process dies pretty
    # quickly.  But if things change so that the process lives for a while, then
    # a different cache aging mechanism should be set up
    unless ($JOB_TO_STATUS) {
        $JOB_TO_STATUS = {};

        my $lsf_file = '/gsc/var/cache/testsuite/lsf-tmp/bjob_query_result.txt';
        my $fh = IO::File->new($lsf_file);
        my $lsf_file_data = do { local( $/ ) ; <$fh> } ;
        $fh->close;
        while ($lsf_file_data =~ m/^(\S+)\s+(\S+)\s+(\S+).*?\n/gm) {
            $JOB_TO_STATUS->{$1} = $3;
        }
        delete $JOB_TO_STATUS->{'JOBID'};
    }
    return $JOB_TO_STATUS;
}



sub get_processing_profile_node {

    my $self = shift;
    my $build = $self->subject;
    my $model = $build->model;
    my $doc = $self->_doc;

    $DB::single = 1;

    my $pp = $model->processing_profile;
    my $pp_name = $pp->name;
    my $pp_type = $pp->type_name;

    my $stages_node = $self->anode("stages","processing_profile",$pp_name);
    $stages_node->addChild( $doc->createAttribute("processing_profile_type", $pp_type));

    if($pp->can('stages')) {

        for my $stage_name ($pp->stages) {
            my $stage_node = $self->anode("stage","value",$stage_name);
            my $commands_node = $doc->createElement("command_classes");
            my $operating_on_node = $doc->createElement("operating_on");

            my @objects = $pp->objects_for_stage($stage_name,$model);
            foreach my $object (@objects) {

                my $object_node;

                #if we have a full blown object (REF), get the object data
                if ( ref(\$object) eq "REF" ) {
                    if ($object->isa('Genome::InstrumentData')) {
                        my $id_node = $self->get_instrument_data_node($object);
                        $object_node = $self->anode("object","value","instrument_data");
                        $object_node->addChild($id_node);
                    } else {
                        $object_node = $self->anode("object","value",$object);
                    }
                } else {
                    $object_node = $self->anode("object","value",$object);
                }

                $operating_on_node->addChild($object_node);
            }

            my @command_classes = $pp->classes_for_stage($stage_name, $model);
            foreach my $classes (@command_classes) {
                #$commands_node->addChild( $self->anode("command_class","value",$classes ) );
                my $command_node =  $self->anode("command_class","value",$classes );
                #get the events for each command class
                $command_node->addChild($self->get_events_for_class_node($classes));
                $commands_node->addChild( $command_node );
            }
            $stage_node->addChild($commands_node);
            $stage_node->addChild($operating_on_node);
            $stages_node->addChild($stage_node);
        }
    }

    return $stages_node;
}

sub get_events_for_class_node {
    my $self = shift;
    my $class = shift;
    my $doc = $self->_doc;
    my $build = $self->subject;

    my $events_list_node = $doc->createElement("events");
    my @events = $class->get( model_id => $build->model->id, build_id => $build->id);

    unless(@events) {
        #Try to find an event for this stage that may not exist anymore
        my @all_events = $build->events;
        my $type = $class->command_name;
        @events = grep($_->event_type =~ /^$type/, @all_events);
    }

    for my $event (@events) {
        my $event_node = $self->get_event_node($event);
        $events_list_node->addChild($event_node);
    }

    return $events_list_node;

}


sub get_instrument_data_node {

    my $self = shift;
    my $object = shift;

    my $id = $self->anode("instrument_data","id", $object->id);
    for (qw/project_name run_name run_identifier read_length library_name library_id lane subset_name run_type gerald_directory id/) {
        if ($object->class ne 'Genome::InstrumentData::Imported' && $object->can($_)) {
            $id->addChild($self->tnode($_, $object->$_));
        } else {
            $id->addChild($self->tnode($_, "N/A")); 
        }     
    }

    return $id;

}

sub get_inputs_node {
    my $self = shift;
    my $doc = $self->_doc;
    my $build = $self->subject;
    
    my $aspect_node = $doc->createElement('aspect');
    $aspect_node->addChild( $doc->createAttribute('name', 'inputs') );

    my @inputs = $build->inputs;
    
    for my $input (@inputs) {
        my $view = $input->create_view(
            perspective => 'default',
            toolkit => 'xml',
            aspects => [ 'name', 'value_class_name', 'value_id' ],
            parent_view => $self,
        );
        
        $view->_generate_content;
        
        my $delegate_xml_doc = $view->_xml_doc;
        my $delegate_root = $delegate_xml_doc->documentElement;
        #cloneNode($deep = 1)
        $aspect_node->addChild( $delegate_root->cloneNode(1) );
    }
    
    return $aspect_node;
}

sub get_links_node {
    my $self = shift;
    my $doc = $self->_doc;
    my $build = $self->subject;
    
    my $links_node = $doc->createElement('links');
    
    my $to_aspect_node = $doc->createElement('aspect');
    $to_aspect_node->addChild( $doc->createAttribute('name', 'to_builds'));
    $links_node->addChild($to_aspect_node);
    
    for my $to_build ( $build->to_builds ) {
        my $view = $to_build->create_view(
            perspective => 'default',
            toolkit => 'xml',
            aspects => ['id'],
            parent_view => $self,
        );
        
        $view->_generate_content;
        
        my $delegate_xml_doc = $view->_xml_doc;
        my $delegate_root = $delegate_xml_doc->documentElement;
        #cloneNode($deep = 1)
        $to_aspect_node->addChild( $delegate_root->cloneNode(1) );
    }
    
    my $from_aspect_node = $doc->createElement('aspect');
    $from_aspect_node->addChild( $doc->createAttribute('name', 'from_builds'));
    $links_node->addChild($from_aspect_node);
    
    for my $from_build ( $build->from_builds ) {
        my $view = $from_build->create_view(
            perspective => 'default',
            toolkit => 'xml',
            aspects => ['id'],
            parent_view => $self,
        );
        
        $view->_generate_content;
        
        my $delegate_xml_doc = $view->_xml_doc;
        my $delegate_root = $delegate_xml_doc->documentElement;
        #cloneNode($deep = 1)
        $from_aspect_node->addChild( $delegate_root->cloneNode(1) );
    }
    
    return $links_node;
}

sub get_lsf_job_status {
    my $self = shift;
    my $lsf_job_id = shift;

    my $result;

    if ( defined($lsf_job_id) ) {

        #check the user specified flag to determine how to retrieve lsf status
        if ($self->use_lsf_file) {
            #get the data from the preloaded hash of lsf info (from file)
            #my %job_to_status = %{$self->_job_to_status};
            #$result = $job_to_status {$lsf_job_id};
            $result = $self->{'_job_to_status'}->{$lsf_job_id};
            if (!defined($result) ) {
                $result = "UNAVAILABLE";
            }
        } else {
            #get the data directly from lsf via bjobs command
            my @lines = `bjobs $lsf_job_id 2>/dev/null`;
            #parse the bjobs output.  get the 3rd field of the 2nd line.
            if ( (scalar(@lines)) > 1) {
                my $line = $lines[1];
                my @fields = split(" ",$line);
                $result = $fields[2];
            } else {
                #if there are no results from bjobs, lsf forgot about the job already.
                $result = "UNAVAILABLE";
            }
        }

    } else {
        #if the input LSF ID is not defined, mark it as unscheduled.
        $result = "UNSCHEDULED";
    }
    return $result;

    #NOTES:  UNSCHEDULED means that an LSF ID exists, but LSF did not have any status on it.  Probably because it was executed a while ago.
    #        UNAVAILABLE means that an LSF ID does NOT exist.
}

sub get_event_node {

    my $self = shift;
    my $event = shift;
    my $doc = $self->_doc;

    my $event_node = $self->anode("event","id",$event->id);
    $event_node->addChild( $doc->createAttribute("command_class",$event->class));
    $event_node->addChild( $self->tnode("event_status",$event->event_status));

    my $lsf_job_id = $event->lsf_job_id;

=pod
    my $root_instance = $self->instance;
    if ($root_instance) {
        my $event_instance;
        foreach my $stage_instance (Workflow::Operation::Instance->get(parent_instance_id => $root_instance->id)) { #$root_instance->child_instances) {
            next unless $stage_instance->can('child_instances');
            #            my @found = $stage_instance->child_instances(
            my @found = Workflow::Operation::Instance->get(
                parent_instance_id => $stage_instance->id,
                name => $event->command_name_brief . ' ' . $event->id
            );
            if (@found) {
                $event_instance = $found[0];
            }
        }

        if ($event_instance) {
            $event_node->addChild( $self->tnode("instance_id", $event_instance->id));
            #            $event_node->addChild( $self->tnode("instance_status", $event_instance->status));

            my @e = Workflow::Operation::InstanceExecution->get(
                instance_id => $event_instance->id
            );

            $event_node->addChild( $self->tnode("execution_count", scalar @e));

            foreach my $current (@e) {
                if ($current->id == $event_instance->current_execution_id) {
                    $event_node->addChild( $self->tnode("instance_status", $current->status));

                    if (!$lsf_job_id) {
                        $lsf_job_id = $current->dispatch_identifier;
                    }

                    last;
                }
            }
        }
    }
=cut

    my $lsf_job_status = $self->get_lsf_job_status($lsf_job_id);

    $event_node->addChild( $self->tnode("lsf_job_id",$lsf_job_id));
    $event_node->addChild( $self->tnode("lsf_job_status",$lsf_job_status));
    $event_node->addChild( $self->tnode("date_scheduled",$event->date_scheduled));
    $event_node->addChild( $self->tnode("date_completed",$event->date_completed));
    $event_node->addChild( $self->tnode("elapsed_time", $self->calculate_elapsed_time($event->date_scheduled,$event->date_completed) ));
    $event_node->addChild( $self->tnode("instrument_data_id",$event->instrument_data_id));
    my $err_log_file = $event->resolve_log_directory ."/".$event->id.".err";
    my $out_log_file = $event->resolve_log_directory ."/".$event->id.".out";
    $event_node->addChild( $self->tnode("output_log_file",$out_log_file));
    $event_node->addChild( $self->tnode("error_log_file",$err_log_file));

    #
    # get alignment director[y|ies] and filter description
    #
    # get list of instrument data assignments
    my @idas = $event->model->instrument_data_assignments;

    if (scalar @idas > 0) {
        # find the events with matching instrument_data_ids
        my @adirs;

        my $processing_profile = $event->model->processing_profile;
        for my $ida (@idas) {
            if ((defined $ida->instrument_data_id && $event->instrument_data_id) && $ida->instrument_data_id == $event->instrument_data_id) {
                my $alignment;
                eval{ ($alignment) = $processing_profile->results_for_instrument_data_assignment($ida)};

                if ($@) {
                    chomp($@);
                    push(@adirs, $@);
                }

                if (defined($alignment)) {
                    push(@adirs, $alignment->alignment_directory);

                    # look for a filter description
                    if ($ida->filter_desc) {
                        $event_node->addChild( $self->tnode("filter_desc", $ida->filter_desc));
                    }
                }
            }
        }
        # handle multiple alignment directories
        if (scalar @adirs > 1) {
            my $i = 1;
            for my $adir (@adirs) {
                $event_node->addChild( $self->tnode("alignment_directory_" . $i, $adir));
                $i++;
            }
        } else {
            $event_node->addChild( $self->tnode("alignment_directory", $adirs[0]));
        }

    }
    return $event_node;
}

sub create_node_with_attribute {

    my $self = shift;
    my $node_name = shift;
    my $attr_name = shift;
    my $attr_value = shift;

    my $doc = $self->_doc;

    my $node = $doc->createElement($node_name);
    $node->addChild($doc->createAttribute($attr_name,$attr_value));
    return $node;

}

#helper methods.  just pass through to the more descriptive names
#anode = attribute node
sub anode {
    my $self = shift;
    return $self->create_node_with_attribute(@_);
}

#tnode = text node
sub tnode {
    my $self = shift;
    return $self->create_node_with_text(@_);
}

sub create_node_with_text {

    my $self = shift;
    my $node_name = shift;
    my $node_value = shift;

    my $doc = $self->_doc;

    my $node = $doc->createElement($node_name);
    if ( defined($node_value) ) {
        $node->addChild($doc->createTextNode($node_value));
    }
    return $node;

}

sub add_attribute {
    my $self = shift;
    my $node = shift;
    my $attr_name = shift;
    my $attr_value = shift;

    my $doc = $self->_doc;

    $node->addChild($doc->createAttribute($attr_name,$attr_value) );
    return $node;

}

sub calculate_elapsed_time {
    my $self = shift;
    my $date_scheduled = shift;
    my $date_completed = shift;

    my $diff;

    if ($date_completed) {
        $diff = UR::Time->datetime_to_time($date_completed) - UR::Time->datetime_to_time($date_scheduled);
    } else {
        $diff = time - UR::Time->datetime_to_time( $date_scheduled);
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
