package Genome::ModelGroup::View::GoldSnpComparison::Xml;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::View::GoldSnpComparison::Xml {
    is => 'UR::Object::View::Default::Xml',
    has_constant => [
        perspective => {
            value => 'gold-snp-comparison',
        },
    ]
};

sub _generate_content {
    my $self = shift;
    my $subject = $self->subject;
    
    return unless $subject;
    
    my @members = $subject->models;
    
    my $id_string = join(' ', map($_->id, @members));
    
    
    my $report_command = Genome::Model::Command::Status::GoldSnpMetrics->create(genome_model_ids=>$id_string,display_output=>0);
    
    unless($report_command->execute) {
        die('Failed to generate content.');
    }
    
    my $doc = $report_command->_doc;
    $self->_xml_doc($doc);
    
    return $doc->toString(1);
}


1;
