package Genome::Sys::Email;

use strict;
use warnings;

use Genome;
use Email::Simple;

use LWP::UserAgent;

class Genome::Sys::Email {
    is => 'UR::Value',
    doc => 'Represents a mailing list message',
    has => [
        list_name => {
            is => 'Text',
            calculate_from => ['id'],
            calculate => q{ ($self->_parse_id($id))[0]; },
            doc => 'The name of the mailing list to which the message was posted',
        },
        month  => {
            is => 'Text',
            calculate_from => ['id'],
            calculate => q{ ($self->_parse_id($id))[1]; },
            doc => 'The month of the archives of the mailing list in which the message can be found',
        },
        message_id => {
            is => 'Text',
            calculate_from => ['id'],
            calculate => q{ ($self->_parse_id($id))[2]; },
            doc => 'The id of the message in the mailing list system',
        },    
        _is_initialized => {
            is => 'Boolean',
            doc => 'Has the data for this email been retrieved/filled in?',
            is_transient => 1,
        },
        _body => {
            is => 'Text',
            doc => 'The body of the message',
            is_transient => 1,
        },
        _subject => {
            is => 'Text',
            doc => 'The subject of the message',
            is_transient => 1,
        },
        mail_server_path => {
            is => 'Text',
            calculate => q{ 'http://gscsmtp.wustl.edu/pipermail' },
        },
        mail_list_path => {
            is => 'Text',
            calculate => q{ 'http://gscsmtp.wustl.edu/cgi-bin/mailman/listinfo' },
        },
    ],
};

sub get {
    my $class = shift;
    my @params = @_;
    
    my $id; #want to verify the ID matches our expected format
    if(scalar(@params) eq 1) {
        $id = $params[0];
    } else {
       my %params = @params;
       if(exists $params{id}) {
           $id = $params{id};
       }
    }
    
    unless($class->_parse_id($id)) {
        return;
    }
    
    return $class->SUPER::get(@_);
}

sub initialize {
    my $self = shift;
    my $source = shift;
    
    if($self->_is_initialized) {
        Carp::confess('Duplicate initialize!');
    }
    
    unless($source) {
        #TODO support looking up the information from the mail server.
        #Just scrape http://gscsmtp.wustl.edu/pipermail/[list]/[year-month]/[message_id].html to extract subject and body 
        Carp::confess('No source object passed to initialize() and loading directly from the mail server is not yet implemented');
    }
    
    if (ref $source eq 'Email::Simple') {
        my $source_id = $source->header('X-Genome-Search-ID');
        unless($source_id eq $self->id) {
            Carp::confess('Source object identifier ' . $source_id . ' does not appear to match this identifier.');
        }
        
        $self->_body($source->body);
        $self->_subject($source->header('Subject'));
    } elsif (ref $source eq 'WebService::Solr::Document') {
        my $source_id = $source->value_for('object_id');
        unless($source_id eq $self->id) {
            Carp::confess('Source object identifier ' . $source_id . ' does not appear to match this identifier.');
        }
        
        $self->_body($source->value_for('content'));
        $self->_subject($source->value_for('title')); 
    } else {
        Carp::confess('Invalid source object ' . $source . ' passed to initialize().');
    }
    
    $self->_is_initialized(1);
    
    return 1;
}

sub is_initialized {
    my $self = shift;
    
    return $self->_is_initialized();
}

sub body {
    my $self = shift;
    
    unless($self->_is_initialized) {
        $self->initialize();
    }
    
    return $self->_body;
}

sub subject {
    my $self = shift;
    
    unless($self->_is_initialized) {
        $self->initialize();
    }
    
    return $self->_subject;
}

sub _parse_id {
    my $class = shift;
    my $id = shift;
    
    my ($list_name, $year_month, $message_id) = split(/\//,$id);
    
    unless($list_name and $year_month and $message_id) {
        return;
    }
    
    return wantarray?
        ($list_name, $year_month, $message_id) :
        $message_id;
}

sub blurb {
    my $self = shift;
    my ($query) = @_; #optionally try to highlight a word in the text
    
    my $text = $self->body;

    $text =~ s/\s{2}/ /g;
    $text =~ s/-------- Original Message --------(.|\n)*//g;
    $text =~ s/\n/ /g;

    my $summarystart = 0;

    if($query) {
        #find summary region around query in result
        my $querypos = index($query, $text);

        if($querypos -75 > $summarystart) {
          $summarystart = $querypos - 75;
        }


    }

    my $summary = substr($text,$summarystart,150);

    if (length($text) > length($summary)) {
        $summary .= ' ...';
    }

    if ($summarystart > 0) {
        $summary = '... ' . $summary;
    }

    return $summary;
}

1;

