package Genome::View::Solr::Xml;

use strict;
use warnings;
use Genome;

use WebService::Solr;

class Genome::View::Solr::Xml {
    is => 'UR::Object::View::Default::Xml',
    is_abstract => 1,
    has => [
        _doc    => {
            is_transient => 1, 
            doc => 'the WebService::Solr::Document object used to generate this view' 
        },
    ],
    has_constant => [
        perspective => {
            value => 'solr',
        },
        type => {
            is_abstract => 1,
            is => 'Text',
            doc => 'The type represented by the document as referred to in Solr--override this in subclasses'
        }
    ],
    doc => 'The base class for creating the XML document that Solr indexes for an object.'
};

sub create {
    my $class = shift;
    my %params = @_;
    
    if(exists $params{content_doc}) {
        return $class->_reconstitute_from_doc($params{content_doc});
    } else {
        return $class->SUPER::create(%params);
    }
}

sub _reconstitute_from_doc {
    my $class = shift;
    my $solr_doc = shift;
    
    unless($solr_doc->isa('WebService::Solr::Document')) {
        $class->error_message('content_doc must be a WebService::Solr::Document');
        return;
    }
    
    my $subject_id = $solr_doc->value_for('object_id');
    unless($subject_id) {
        #Fall back on old way of getting id--this can be removed after all snapshots in use set object_id in Solr
        $subject_id = $solr_doc->value_for('id');
        ($subject_id) = $subject_id =~ m/.*?(\d+)$/;
    }
    
    my $subject_class_name = $solr_doc->value_for('class');
    
    my $self = $class->SUPER::create(subject_id => $subject_id, subject_class_name => $subject_class_name);
    
    $self->_doc($solr_doc);
    
    my $widget = $self->widget();
    my ($content_ref,$fh) = @$widget;
    $$content_ref = $self->_doc->to_xml;
    
    return $self;
}


sub content_doc {
    my $self = shift;
    my $content = $self->content; #force document generation
    return $self->_doc;
}

sub _generate_content {
    my $self = shift;
    
    my $subject = $self->subject;
    return unless $subject;
    
    my @fields = ();
    
    #Make it easy to override some or all of the fields in subclasses.

    my $class = $self->_generate_class_field_data;
    my $title = $self->_generate_title_field_data;
    my $id =    $self->_generate_id_field_data;
    my $object_id = $self->_generate_object_id_field_data;
    my $timestamp = $self->_generate_timestamp_field_data;
    my $content = $self->_generate_content_field_data;
    my $type = $self->_generate_type_field_data;

    push @fields, WebService::Solr::Field->new( class => $class );
    push @fields, WebService::Solr::Field->new( title => $title );
    push @fields, WebService::Solr::Field->new( id => $id );
    push @fields, WebService::Solr::Field->new( object_id => $object_id);
    push @fields, WebService::Solr::Field->new( timestamp => $timestamp );
    push @fields, WebService::Solr::Field->new( content => $content );
    push @fields, WebService::Solr::Field->new( type => $type );


    
    # WARNING! There exists code in Genome::Search that is trying to reuse objects;
    # when it does so, calling $self->property() doesnt work out so well since $self is
    # the old object that is being reused and property() gets you the OLD property
    # ...turning the recycling off for now


    # required to display result
    push @fields, WebService::Solr::Field->new( display_title => $self->_generate_display_title_field_data() );
    push @fields, WebService::Solr::Field->new( display_type  => $self->display_type() );
    push @fields, WebService::Solr::Field->new( display_icon_url  => $self->display_icon_url() );

    # optional to display result
    # notice there is no display_content? plan is to generate "display_content" with highlighted area that matched
    push @fields, WebService::Solr::Field->new( display_url0  => $self->display_url0() );

    if ($self->display_label1 && $self->display_url1) {
        push @fields, WebService::Solr::Field->new( display_label1 => $self->display_label1() );
        push @fields, WebService::Solr::Field->new( display_url1   => $self->display_url1() );
    }

    if ($self->display_label2 && $self->display_url2) {
        push @fields, WebService::Solr::Field->new( display_label2 => $self->display_label2() );
        push @fields, WebService::Solr::Field->new( display_url2   => $self->display_url2() );
    }

    if ($self->display_label3 && $self->display_url3) {
        push @fields, WebService::Solr::Field->new( display_label3 => $self->display_label3() );
        push @fields, WebService::Solr::Field->new( display_url3   => $self->display_url3() );
    }


    $self->_doc( WebService::Solr::Document->new(@fields) );
    return $self->_doc->to_xml;
}


sub _generate_display_title_field_data {

    my ($self) = @_;
    my $subject = $self->subject;
    
    my @aspects = $self->aspects;
    my @display_title_aspects = grep($_->position eq 'display_title', @aspects);
    die "TWO display_title properties are defined in xml for solr submitting" if @display_title_aspects > 1;

    my $method = $display_title_aspects[0]->name();
    my $display_title = $subject->$method();
    return $display_title;
}


sub _generate_class_field_data {
    my $self = shift;
    my $subject = $self->subject;
    
    return $subject->class;
}

sub _generate_title_field_data {
    my $self = shift;
    my $subject = $self->subject;
    
    my @aspects = $self->aspects;
    my @title_aspects = grep($_->position eq 'title', @aspects);
    
    my $title;
    
    if(scalar @title_aspects) {
        my @title_parts;
        
        for my $aspect (@title_aspects) {
            my $property = $aspect->name;
            
            my $value = $subject->$property;
            
            $value = '' unless defined $value; #Not useful for indexing, but will add an extra space in case anyone cares.
            
            push @title_parts, $value;
        }
        
        $title = join(' ', @title_parts);   
    }

    unless($title) {
        if($subject->can('name') and $subject->name) {
            $title = $subject->name;
        } else {
            $title = $self->type . ' ' . $subject->id;
        }
    }
       
    return $title;
}

sub _generate_id_field_data {
    my $self = shift;
    my $subject = $self->subject;
    
    #TODO after all code is setting solr_id, make that field the primary id for Solr;
    #then remove the class and '---' from this field
    return $subject->class . '---' . $subject->id;
}

sub _generate_object_id_field_data {
    my $self = shift;
    my $subject = $self->subject;
    
    return $subject->id;
}

sub _generate_timestamp_field_data {
    my $self = shift;
    my $subject = $self->subject;
    
    my @aspects = $self->aspects;
    my @timestamp_aspects = grep($_->position eq 'timestamp', @aspects);

    #By convention this timestamp is used when we don't know the real timestamp
    my $timestamp = '1999-01-01T01:01:01Z';
    
    if(scalar @timestamp_aspects) {
        if(scalar @timestamp_aspects > 1) {
            $self->error_message('Only one timestamp may be supplied.');
            die $self->error_message;
        }
        my $aspect = $timestamp_aspects[0];
        my $property = $aspect->name;
            
        my $value = $subject->$property;
        
        if($value) {
            my $solr_timestamp_format = qr(\d{4}-\d{1,2}-\d{1,2}T\d{1,2}:\d{1,2}:\d{1,2}Z);
            
            if($value =~ $solr_timestamp_format) {
                $timestamp = $value;
            } else {
                my ($a, $b) = split / /, $value;
                $b =~ s/.\d{6}$//g;
                $timestamp = sprintf("%sT%sZ", $a, $b);
            }
            
            unless($timestamp =~ '\d{4}-\d{1,2}-\d{1,2}T\d{1,2}:\d{1,2}:\d{1,2}Z') {
                $self->error_message('Could not parse timestamp: ' . $timestamp . '(format should be yyyy-mm-ddThh:mm:ssZ)');
                die $self->error_message;
            }
        }
    }
    
    return $timestamp;
}

sub _generate_content_field_data {
    my $self = shift;
    my $subject = $self->subject;
    
    my @aspects = $self->aspects;
    my @content_aspects = grep($_->position eq 'content', @aspects);

    my @content;
    
    if(scalar @content_aspects) {
        for my $aspect (@content_aspects) {
            #Use the text view as we don't want result wrapped in <aspect> tag, so skip up the hierarchy past XML to text
            my $value = $self->UR::Object::View::Default::Text::_generate_content_for_aspect($aspect);
            $value = '' unless defined $value; #Not useful for indexing, but will add an extra space in case anyone cares.
            
            push @content, $value;
        }
    }
    
    my $content = join("\n", @content);
    
    $content ||= $subject->id;
    
    return $content;
}

sub _generate_type_field_data {
    my $self = shift;
    my $subject = $self->subject;
    
    return $self->type;
}


1;
