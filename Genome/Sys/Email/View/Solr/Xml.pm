package Genome::Sys::Email::View::Solr::Xml;

use strict;
use warnings;

use Genome;

class Genome::Sys::Email::View::Solr::Xml {
    is => 'Genome::View::Solr::Xml',
    has_constant => [
        type => {
            is => 'Text',
            default => 'mail'
        },
        default_aspects => {
            is => 'ARRAY',
            default => [
                {
                    name => 'subject',
                    position => 'title',
                },
                {
                    name => 'body',
                    position => 'content',
                }
            ],
        }
    ]
};

sub _reconstitute_from_doc {
    my $class = shift;
    my $solr_doc = shift;
    
    unless($solr_doc->isa('WebService::Solr::Document')) {
        $class->error_message('content_doc must be a WebService::Solr::Document');
        return;
    }
    
    my $subject_class_name = $solr_doc->value_for('class');
    my $subject_id = $solr_doc->value_for('object_id');
    unless($subject_class_name eq 'Genome::Sys::Email') {
        $class->error_message('content_doc for this view must point to a Genome::Sys::Email');
        return;
    }
    
    my $mail = $subject_class_name->get($subject_id);
    unless($mail) {
        $class->error_message('Could not get Genome::Sys::Email object.');
    }
    
    unless($mail->is_initialized) {
        $mail->initialize($solr_doc);
    }
    
    return $class->SUPER::_reconstitute_from_doc($solr_doc, @_);
}

1;
