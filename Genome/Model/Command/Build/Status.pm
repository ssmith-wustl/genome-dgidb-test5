package Genome::Model::Command::Build::Status;

use strict;
use warnings;
use Genome;
use Data::Dumper;
use XML::LibXML;

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
            section => {
                is => 'String',
                doc => "The sub-section of the document to return.  Options are 'all', 'events', etc.", 
            }, 
            _doc => {
                  is => 'XML::LibXML::Document',
                  doc => "The XML tool used to create all nodes of the output XML tree.",
            },
   ],
    
};

sub execute  {
    my $self = shift;
    my $return_value = 1;
   
    if ( !defined($self->build) ) {
        $self->build(Genome::Model::Build->get(build_id => $self->build_id) ); 
    }

    #create the XML doc and add it to the object 
    my $doc = XML::LibXML->createDocument();
    $self->_doc($doc);

    my $buildnode = $doc->createElement("build");

    my $model = $self->build->model;

    $buildnode->addChild( $doc->createAttribute("model-id",$model->id) );
    $buildnode->addChild( $doc->createAttribute("build-id",$self->build_id) );
    $buildnode->addChild( $doc->createAttribute("status",$self->build->build_status) );
    my $time = UR::Time->now(); 
    $buildnode->addChild( $doc->createAttribute("status-generated-at",$time) );
 
    $buildnode->addChild ( $self->get_processing_profile_node() );
    
    #TODO:  add method to build for logs, reports
    $buildnode->addChild ( $self->tnode("logs","") );
    $buildnode->addChild ( $self->tnode("reports","") );
 
    my $events_list = $doc->createElement("events");
    my @events = $self->build->events;

    for my $event (@events) {
        my $event_node = $self->get_event_node($event);
        $events_list->addChild($event_node);
    }
 
    $buildnode->addChild($events_list);

    #print Dumper(@events);

    $doc->setDocumentElement($buildnode); 
    return $doc->toString(1);

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
            $commands_node->addChild( $self->anode("command_class","value",$classes ) ); 
        }
        $stage_node->addChild($commands_node);
        $stage_node->addChild($operating_on_node);
        $stages_node->addChild($stage_node);
    }

    return $stages_node;
}

sub get_instrument_data_node {
  
    my $self = shift;
    my $object = shift; 

    my $id = $self->anode("instrument_data","id",$object->genome_model_run_id);
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
    } else {
        #if the incoming LSF ID is not defined, mark it as unscheduled.
        $result = "UNSCHEDULED";
    }
    return $result;
}

sub get_event_node {
    
    my $self = shift; 
    my $event = shift;
    my $doc = $self->_doc;

    my $lsf_job_status = $self->get_lsf_job_status($event->lsf_job_id);

    my $event_node = $self->anode("event","id",$event->id);
    $event_node->addChild( $doc->createAttribute("command_class",$event->class)); 
        $event_node->addChild( $self->tnode("event_status",$event->event_status));
        $event_node->addChild( $self->tnode("lsf_job_id",$event->lsf_job_id));
        $event_node->addChild( $self->tnode("lsf_job_status",$lsf_job_status));
        $event_node->addChild( $self->tnode("date_scheduled",$event->date_scheduled));
        $event_node->addChild( $self->tnode("date_completed",$event->date_completed));
        $event_node->addChild( $self->tnode("instrument_data_id",$event->instrument_data_id));
        my $log_file = $event->resolve_log_directory ."/".$event->id.".err";
        $event_node->addChild( $self->tnode("log_file",$log_file));
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


1;

