package Genome::Sys::Email::View::Solr::Xml;

use strict;
use warnings;

use Genome;

class Genome::Sys::Email::View::Solr::Xml {
    is => 'Genome::View::Solr::Xml',
    has => [
        type => {
            is => 'Text',
            default => 'mail'
        },
        display_type => {
            is => 'Text',
            default => 'Wiki Page',
        },
        display_icon_url => {
            is  => 'Text',
            default => 'genome_wiki_document_32',
        },
        display_url0 => {
            is => 'Text',
            calculate => q{ return build_url0(@_); },
        },
        display_label1 => {
            is  => 'Text',
        },
        display_url1 => {
            is  => 'Text',
        },
        display_label2 => {
            is  => 'Text',
        },
        display_url2 => {
            is  => 'Text',
        },
        display_label3 => {
            is  => 'Text',
        },
        display_url3 => {
            is  => 'Text',
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
                },
                {
                    name => '__display_name__',
                    position => 'display_title',
                }
            ],
        }
    ]
};

sub build_url0 {

    my ($self) = @_;


}

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
