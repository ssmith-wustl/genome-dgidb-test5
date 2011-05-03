package Genome::Model::View::Status::Xml;

use strict;
use warnings;

use Genome;

class Genome::Model::View::Status::Xml {
    is => 'Genome::View::Status::Xml',
    has_constant => [
        default_aspects => {
            is => 'ARRAY',
            value => [
                'genome_model_id',
                'name',
                'subject_id',
                'subject_name',
                'subject_class_name',
                # {
                #     name => 'subject',
                #     aspects => [ '__display_name__' ],
                #     perspective => 'default',
                #     toolkit => 'xml'
                # },
                'is_default',
                'data_directory',
                'creation_date',
                'user_name',
                {
                    name => 'builds',
                    aspects => [
                        'id', 'data_directory', 'status', 'date_scheduled', 'date_completed',
                    ],
                    perspective => 'default',
                    toolkit => 'xml',
                    subject_class_name => 'Genome::Model::Build',
                },
                {
                    name => 'last_complete_build',
                    aspects => [
                        'id', 'data_directory'
                    ],
                    perspective => 'default',
                    toolkit => 'xml',
                    subject_class_name => 'Genome::Model::Build',
                },
                {
                    name => 'inputs',
                    aspects => [
                        'value_id',
                        'name',
                        'value',
                        'value_class_name',
                    ],
                    perspective => 'default',
                    toolkit => 'xml',
                },
                {
                    name => 'to_models',
                    aspects => [
                        'name', 'id',
                    ],
                    perspective => 'default',
                    toolkit => 'xml',
                },
                                {
                    name => 'from_models',
                    aspects => [
                        'name', 'id',
                    ],
                    perspective => 'default',
                    toolkit => 'xml',
                },
            ]
        }
    ]
};

1;

=pod

=head1 NAME

Genome::Model::View::Status::XML - status summary for models in XML format

=head1 SYNOPSIS

$m = Genome::Model->get(1234);
$v = Genome::Model::View::Status::Xml->create(subject => $m);
$xml = $v->content;

=head1 DESCRIPTION

This view renders the summary of a model's status in XML format.

=cut

