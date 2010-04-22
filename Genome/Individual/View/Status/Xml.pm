package Genome::Individual::View::Status::Xml;

use strict;
use warnings;
use Genome;
use Data::Dumper;
use XML::LibXML;

class Genome::Individual::View::Status::Xml {
    is => 'Genome::View::Status::Xml',
    has_constant => [
        default_aspects => {
            is => 'ARRAY',
            value => [
                'id',
                'name',
                'common_name',
                'gender',
                {
                    name => 'samples',
                    perspective => 'default',
                    toolkit => 'xml',
                    aspects => [
                        'id',
                        'name',
                        {
                            name => 'models',
                            perspective => 'default',
                            toolkit => 'xml',
                            aspects => [
                                'genome_model_id',
                                'name',
                                'subject_id',
                                'subject_class_name',
                                'is_default',
                                'data_directory',
                                {
                                    name => 'processing_profile',
                                    aspects => ['id', 'name'],
                                    perspective => 'default',
                                    toolkit => 'xml'
                                },
                                'creation_date',
                                'user_name',
                                {
                                    name => 'builds',
                                    aspects => [ 'id', 'data_directory', 'status', 'date_scheduled', 'date_completed', ],
                                    perspective => 'default',
                                    toolkit => 'xml',
                                    subject_class_name => 'Genome::Model::Build',
                                }
                            ],
                            subject_class_name => 'Genome::Model',
                        }
                    ]
                }
            ]
        }
    ]
};

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

