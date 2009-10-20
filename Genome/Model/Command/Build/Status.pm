package Genome::Model::Command::Build::Status;

use strict;
use warnings;
use Genome;
use Data::Dumper;
use XML::LibXML;
use XML::LibXSLT;

class Genome::Model::Command::Build::Status {
    is => ['Command'],
    has => [
            build_id => {
                is => 'String',
                doc => 'Required id of build to report status on.',
            },
            build   => {
                is => 'Genome::Model::Build',
                id_by => 'build_id',
                doc => "The Build of a genome model to report status on.",
            },
    ],
    has_optional => [
            instance_id => {
                is => 'String',
                doc => 'Optional id of the workflow operation instance to use.'
            },
            instance => {
                is => 'Workflow::Store::Db::Operation::Instance',
                id_by => 'instance_id',
            },
            section => {
                is => 'String',
                doc => "NOT IMPLEMENTED YET.  The sub-section of the document to return.  Options are 'all', 'events', etc.",
            },
            display_output => {
                is => 'Integer',
                default_value => 1,
                doc => "A flag which lets the user supress the display of XML output to the screen.",
            },
            output_format => {
                is => 'Text',
                default_value => 'xml',
                doc => "Parameter which allows the user to specify HTML as an output option.",
            },
            xsl_file => {
                is => 'Text',
                doc => "Parameter which allows the user to specify the XSL file to transform the output by.",
            },

            use_lsf_file => {
                is => 'Integer',
                default_value => 0,
                doc => "A flag which lets the user retrieve LSF status from a temporary file rather than using a bjobs command to retrieve the values.",
            },
            _doc => {
                  is => 'XML::LibXML::Document',
                  doc => "The XML tool used to create all nodes of the output XML tree.",
            },
            _xml => {
                  is => 'Text',
                  doc => "The XML generated by the status call.",
            },
            _job_to_status => {
                  is => 'HASH',
                  doc => "The XML generated by the status call.",
            },


   ],
    doc => "show the status of a new/running/complete build",
};

sub sub_command_sort_position { 1 }

sub execute  {
    my $self = shift;
    my $return_value = 1;

    #create _job_to_status hash
    if ($self->use_lsf_file) {
        my %job_status_hash = $self->load_lsf_job_status();
        $self->_job_to_status(\%job_status_hash);
    }

    #create the XML doc and add it to the object
    my $doc = XML::LibXML->createDocument();
    $self->_doc($doc);

    #create the xml nodes and fill them up with data
    #root node
    my $build_status_node = $doc->createElement("build-status");
    my $time = UR::Time->now();
    $build_status_node->addChild( $doc->createAttribute("generated-at",$time) );

    #build node
    my $buildnode = $self->get_build_node;
    $build_status_node->addChild($buildnode);


    ## find the latest workflow for this build
    unless ($self->instance) {
        my @ops = sort { $b->id <=> $a->id } Workflow::Store::Db::Operation::Instance->get(
            name => $self->build->id . ' all stages'
        );

        if (defined $ops[0]) {
            $self->instance($ops[0]);
        }
    }

    if ($self->instance) {
        # silly UR tricks to get everything i'm interested in loaded into the cache in 2 queries

#        my @exec_ids = map {
#            $_->current_execution_id
#        } (Workflow::Store::Db::Operation::Instance->get(
#            id => $self->instance->id,
#            -recurse => ['parent_instance_id','instance_id']
#        ));

        my @exec_ids = map {
            $_->current_execution_id
        } (Workflow::Store::Db::Operation::Instance->get(
            sql => 'select workflow_instance.workflow_instance_id
                      from workflow_instance
                     start with workflow_instance.parent_instance_id = ' . $self->instance->id . '
                     connect by workflow_instance.parent_instance_id = prior workflow_instance.workflow_instance_id'
        ));

        my @ex = Workflow::Store::Db::Operation::InstanceExecution->get(
            instance_id => { operator => '[]', value=>\@exec_ids }
        );

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
    $self->_xml($doc->toString(1) );

    #print to the screen if desired
    if ( $self->display_output ) {
       if ( lc $self->output_format eq 'html' ) {
            print $self->to_html($self->_xml);
       } else {
            print $self->_xml;
       }
    }

    return $return_value;
}

sub xml {
    my $self = shift;
    return $self->_xml;
}

sub get_root_node {
    my $self = shift;
    return $self->_doc;
}


sub get_reports_node {
    my $self = shift;

    my $report_dir = $self->build->resolve_reports_directory;
    my $reports_node = $self->anode("reports", "directory", $report_dir);
    my @report_list = $self->build->reports;
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
    my @events = $self->build->events;

    for my $event (@events) {
        $DB::single = 1;
        my $event_node = $self->get_event_node($event);
        $events_list->addChild($event_node);
    }

    return $events_list;

}

sub get_build_node {

    my $self = shift;
    my $doc = $self->_doc;

    my $buildnode = $doc->createElement("build");

    my $model = $self->build->model;

    $buildnode->addChild( $doc->createAttribute("model-name",$model->name) );
    $buildnode->addChild( $doc->createAttribute("model-id",$model->id) );
    $buildnode->addChild( $doc->createAttribute("build-id",$self->build_id) );
    $buildnode->addChild( $doc->createAttribute("status",$self->build->build_status) );
    $buildnode->addChild( $doc->createAttribute("data-directory",$self->build->data_directory) );
    $buildnode->addChild( $doc->createAttribute("lsf-job-id", $self->build->build_event->lsf_job_id));

    my $event = $self->build->build_event;

    my $out_log_file = $event->resolve_log_directory . "/" . $event->id . ".out";
    my $err_log_file = $event->resolve_log_directory . "/" . $event->id . ".err";

    if (-e $out_log_file) {
        $buildnode->addChild( $doc->createAttribute("output-log",$out_log_file));
    }
    if (-e $err_log_file) {
        $buildnode->addChild( $doc->createAttribute("error-log",$err_log_file));
    }

    return $buildnode;
}

sub get_workflow_node {
    my $self = shift;
    my $doc = $self->_doc;

    my $workflownode = $doc->createElement("workflow");

    $workflownode->addChild( $doc->createAttribute("instance-id", $self->instance->id));
    $workflownode->addChild( $doc->createAttribute("instance-status", $self->instance->status));

    return $workflownode;
}

#Note:  Since the Web server cannot execute bjob commands, use the cron'd results from the tmp file
sub load_lsf_job_status {
    my $self = shift;

    my %job_to_status;
    my $lsf_file = '/gsc/var/cache/testsuite/lsf-tmp/bjob_query_result.txt';
    my @bjobs_lines = IO::File->new($lsf_file)->getlines;
    shift(@bjobs_lines);
    for my $bjob_line (@bjobs_lines) {
        my @job = split(/\s+/,$bjob_line);
        $job_to_status{$job[0]} = $job[2];
    }
    return %job_to_status;
}

sub get_processing_profile_node {

    my $self = shift;
    my $model = $self->build->model;
    my $doc = $self->_doc;

    my $pp = $model->processing_profile;
    my $pp_name = $pp->name;

    my $stages_node = $self->anode("stages","processing_profile",$pp_name);

    for my $stage_name ($pp->stages) {
        my $stage_node = $self->anode("stage","value",$stage_name);
        my $commands_node = $doc->createElement("command_classes");
        my $operating_on_node = $doc->createElement("operating_on");

        my @objects = $pp->objects_for_stage($stage_name,$model);
        foreach my $object (@objects) {

            my $object_node;

            #if we have a full blown object (REF), get the object data
            if ( ref(\$object) eq "REF" ) {
                if ( $object->class eq "Genome::InstrumentData::Solexa" ) {
                    my $id_node = $self->get_instrument_data_node($object);
                    $object_node = $self->anode("object","value","instrument_data");
                    $object_node->addChild($id_node);
                }
            } else {
                 $object_node = $self->anode("object","value",$object);
            }

            $operating_on_node->addChild($object_node);
        }

        my @command_classes = $pp->classes_for_stage($stage_name);
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

    return $stages_node;
}

sub get_events_for_class_node {
    my $self = shift;
    my $class = shift;
    my $doc = $self->_doc;

    my $events_list_node = $doc->createElement("events");
    my @events = $class->get( model_id => $self->build->model->id, build_id => $self->build->build_id);

    for my $event (@events) {
        my $event_node = $self->get_event_node($event);
        $events_list_node->addChild($event_node);
    }

    return $events_list_node;

}



sub get_instrument_data_node {

    my $self = shift;
    my $object = shift;

    #print Dumper($object);

    my $id = $self->anode("instrument_data","id",$object->id);
    $id->addChild( $self->tnode("project_name",$object->project_name));
    $id->addChild( $self->tnode("sample_name",$object->sample_name));
    $id->addChild( $self->tnode("run_name",$object->run_name) );
    $id->addChild( $self->tnode("flow_cell_id",$object->flow_cell_id) );
    $id->addChild( $self->tnode("read_length",$object->read_length) );
    $id->addChild( $self->tnode("library_name",$object->library_name) );
    $id->addChild( $self->tnode("library_id",$object->library_id) );
    $id->addChild( $self->tnode("lane",$object->lane));
    $id->addChild( $self->tnode("subset_name",$object->subset_name));
    $id->addChild( $self->tnode("seq_id",$object->seq_id));
    $id->addChild( $self->tnode("run_type",$object->run_type));
    $id->addChild( $self->tnode("gerald_directory",$object->gerald_directory));

    return $id;

}

sub get_lsf_job_status {
    my $self = shift;
    my $lsf_job_id = shift;

    my $result;

    if ( defined($lsf_job_id) ) {

        #check the user specified flag to determine how to retrieve lsf status
        if ($self->use_lsf_file) {
            #get the data from the preloaded hash of lsf info (from file)
            my %job_to_status = %{$self->_job_to_status};
            $result = $job_to_status {$lsf_job_id};
            if (!defined($result) ) {
                $result = "UNAVAILABLE";
            }
        } else {
            #get the data directly from lsf via bjobs command
            my @lines = `bjobs $lsf_job_id`;
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

    $DB::single = 1;
    my $event_node = $self->anode("event","id",$event->id);
    $event_node->addChild( $doc->createAttribute("command_class",$event->class));
    $event_node->addChild( $self->tnode("event_status",$event->event_status));

    my $lsf_job_id = $event->lsf_job_id;

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

            my @e = Workflow::Store::Db::Operation::InstanceExecution->get(
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
		for my $ida (@idas) {
		  $DB::single = 1;
		  my $alignment = $ida->alignment;
          if (defined($alignment)) {
		    if ($alignment->instrument_data_id == $event->instrument_data_id) {
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

sub to_html {

    my $self = shift;
    my $result = shift;

    my $parser = XML::LibXML->new;
    my $xslt = XML::LibXSLT->new;

    my $template;
    my @template_lines;
    if ( defined($self->xsl_file) ) {
        my $fh = Genome::Utility::FileSystem->open_file_for_reading($self->xsl_file);
        while (my $line = $fh->getline()) {
            push @template_lines,$line;
        }
        $fh->close();
    } else {
        @template_lines = <DATA>;
    }
    $template = join("",@template_lines);

    my $source = $parser->parse_string($result);
    my $style_doc = $parser->parse_string($template);
    my $stylesheet = $xslt->parse_stylesheet($style_doc);

    my $results = $stylesheet->transform($source);
    return $stylesheet->output_string($results);

}

1;
__DATA__
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:template match="/">

    <html>
      <head>
        <title>Build <xsl:value-of select="build-status/build/@build-id"/> Status</title>
        <link rel="stylesheet" href="https://gscweb.gsc.wustl.edu/report_resources/apipe_dashboard/css/master.css" type="text/css" media="screen" />
      </head>

      <body>
        <div class="container">
          <div class="background">
            <h1 class="page_title">Build <xsl:value-of select="build-status/build/@build-id"/> Status</h1>
            <div class="page_padding">
              <table width="100%" cellpadding="0" cellspacing="0" border="0">
                <colgroup>
                  <col width="50%"/>
                  <col width="50%"/>
                </colgroup>
                <tr>
                  <td>
                    <table border="0" cellpadding="0" cellspacing="0" class="info_table">
                      <tr><td class="label">Status:</td><td class="value"><xsl:value-of select="build-status/build/@status" /></td></tr>
                      <tr><td class="label">Build:</td><td class="value"><xsl:value-of select="build-status/build/@build-id"/></td></tr>
                      <tr><td class="label">Data Directory:</td><td class="value"><a><xsl:attribute name="href"><xsl:value-of select="build-status/build/@data-directory"/></xsl:attribute>           <xsl:value-of select="build-status/build/@data-directory"/></a></td></tr>
                    </table>
                  </td>
                  <td>
                    <table border="0" cellpadding="0" cellspacing="0" class="info_table">
                      <tr><td class="label">Model ID:</td><td class="value"><xsl:value-of select="build-status/build/@model-id"/></td></tr>
                      <tr><td class="label">Model Name:</td><td class="value"><xsl:value-of select="build-status/build/@model-name"/></td></tr>
                      <tr><td class="label">Processing Profile:</td><td class="value"><xsl:value-of select="build-status/build/stages/@processing_profile"/></td></tr>
                    </table>
                  </td>
                </tr>
              </table>
              <table border="0" cellpadding="0" cellspacing="0" class="stages" width="100%">
                <tr>
                  <xsl:for-each select="build-status/build/stages/stage[count(command_classes/*) > 0]">
                    <td>
                      <table class="stage" border="0" cellpadding="0" cellspacing="0" width="100%">

                        <tr>
                          <th colspan="2">
                            <xsl:variable name="stage_name" select="@value"/>
                            <xsl:value-of select="translate($stage_name,'_', ' ')"/>
                          </th>
                        </tr>

                        <xsl:variable name="num_succeeded" select="count(descendant::*/event_status[text()='Succeeded'])"/>
                        <xsl:variable name="num_succeeded_label">
                        <xsl:choose>
                            <xsl:when test="$num_succeeded = 0">ghost</xsl:when>
                            <xsl:otherwise>label</xsl:otherwise>
                        </xsl:choose>
                        </xsl:variable>

                        <xsl:variable name="num_scheduled" select="count(descendant::*/event_status[text()='Scheduled'])"/>
                        <xsl:variable name="num_scheduled_label">
                        <xsl:choose>
                            <xsl:when test="$num_scheduled = 0">ghost</xsl:when>
                            <xsl:otherwise>label</xsl:otherwise>
                        </xsl:choose>
                        </xsl:variable>

                        <xsl:variable name="num_running" select="count(descendant::*/event_status[text()='Running'])"/>
                        <xsl:variable name="num_running_label">
                        <xsl:choose>
                            <xsl:when test="$num_running = 0">ghost</xsl:when>
                            <xsl:otherwise>label</xsl:otherwise>
                        </xsl:choose>
                        </xsl:variable>

                        <xsl:variable name="num_abandoned" select="count(descendant::*/event_status[text()='Abandoned'])"/>
                        <xsl:variable name="num_abandoned_label">
                        <xsl:choose>
                            <xsl:when test="$num_abandoned = 0">ghost</xsl:when>
                            <xsl:otherwise>label</xsl:otherwise>
                        </xsl:choose>
                        </xsl:variable>

                        <xsl:variable name="num_failed" select="count(descendant::*/event_status[text()='Crashed' or text()='Failed'])"/>
                        <xsl:variable name="num_failed_label">
                        <xsl:choose>
                            <xsl:when test="$num_failed = 0">ghost</xsl:when>
                            <xsl:otherwise>label</xsl:otherwise>
                        </xsl:choose>
                        </xsl:variable>


                        <tr><xsl:attribute name="class"><xsl:value-of select="$num_scheduled_label"/></xsl:attribute>
                         <td class="label">
                            Scheduled:
                          </td>
                          <td class="value">
                            <xsl:value-of select="$num_scheduled"/>
                          </td>

                        </tr>

                        <tr><xsl:attribute name="class"><xsl:value-of select="$num_running_label"/></xsl:attribute>
                          <td class="label">
                            Running:
                          </td>
                          <td class="value">
                            <xsl:value-of select="$num_running"/>
                          </td>
                        </tr>

                        <tr><xsl:attribute name="class"><xsl:value-of select="$num_succeeded_label"/></xsl:attribute>
                          <td class="label">
                            Succeeded:
                          </td>
                          <td class="value">
                            <xsl:value-of select="$num_succeeded"/>
                          </td>
                        </tr>

                        <tr><xsl:attribute name="class"><xsl:value-of select="$num_abandoned_label"/></xsl:attribute>
                          <td class="label">
                            Abandoned:
                          </td>
                          <td class="value">
                            <xsl:value-of select="$num_abandoned"/>
                          </td>
                        </tr>

                        <tr><xsl:attribute name="class"><xsl:value-of select="$num_failed_label"/></xsl:attribute>
                          <td class="label">
                            Crashed/Failed:
                          </td>
                          <td class="value">
                            <xsl:value-of select="$num_failed"/>
                          </td>
                        </tr>

                        <tr>
                          <td class="label">
                            Total:
                          </td>
                          <td class="value">
                            <xsl:value-of select="count(descendant::*/event_status)"/>
                          </td>
                        </tr>
                      </table>
                    </td>
                  </xsl:for-each>
                </tr>
              </table>

            <hr/>

              <xsl:for-each select="//stage[count(command_classes/*) > 0 ]">
              <h3>
                <xsl:variable name="stage_name" select="@value"/>
                <xsl:value-of select="translate($stage_name,'_', ' ')"/>
              </h3>
              <table class="alignment_detail" width="100%" cellspacing="0" cellpadding="0" border="0">
                <colgroup>
                    <col width="40%"/>
                    <col/>
                    <col/>
                    <col/>
                    <col/>
                </colgroup>
                <tr>
                    <th>
                    <xsl:choose><xsl:when test="@value='alignment'">Flow Cell</xsl:when>
                    <xsl:otherwise>Event</xsl:otherwise>
                    </xsl:choose>
                    </th>

                    <th>Status</th><th>Scheduled</th><th>Completed</th><th class="last">Elapsed</th>
                </tr>
                <xsl:for-each select="descendant::*/event">
                <tr>
                    <td>
                        <xsl:choose>
                            <xsl:when test="instrument_data_id!=''">
                                <xsl:variable name="inst_data_id" select="instrument_data_id" />
                                <xsl:for-each select="//instrument_data[@id=$inst_data_id]" >
                                    <xsl:choose>
                                        <xsl:when test="gerald_directory">
                                            <a><xsl:attribute name="href"><xsl:value-of select="gerald_directory"/></xsl:attribute>
                                            <xsl:value-of select="flow_cell_id"/>
                                            </a>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:value-of select="flow_cell_id"/>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </xsl:for-each>
                            </xsl:when>
                       <xsl:otherwise>
                                <xsl:variable name="full_command_class" select="@command_class" />
                                <!-- <xsl:value-of select="@command_class"/> -->
                                <xsl:value-of select="substring-after($full_command_class,'Genome::Model::Command::Build::')"/>
                        </xsl:otherwise>
                        </xsl:choose>
                    </td>

                    <td>
                        <a>
                        <xsl:attribute name="href">
                            <xsl:value-of select="log_file"/>
                        </xsl:attribute>
                        <xsl:value-of select="event_status"/>
                        </a>
                    </td>
                    <!-- <td><xsl:value-of select="event_status"/></td> -->
                    <td><xsl:value-of select="date_scheduled"/></td>
                    <td><xsl:value-of select="date_completed"/></td>
                    <td class="last"><xsl:value-of select="elapsed_time"/></td>
                </tr>
                </xsl:for-each>
              </table>
              </xsl:for-each>

            </div>
          </div>
        </div>
      </body>
    </html>

  </xsl:template>

</xsl:stylesheet>
