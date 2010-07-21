package Genome::ModelGroup::View::Coverage::Xml;

class Genome::ModelGroup::View::Coverage::Xml {
    is => 'UR::Object::View::Default::Xml',
};

sub _generate_content {
    my $self = shift;
    my $subject = $self->subject();

    my $xml_doc = XML::LibXML->createDocument();
    $self->_xml_doc($xml_doc);

    my $object = $xml_doc->createElement('object');
    $xml_doc->setDocumentElement($object);
    my $time = UR::Time->now();
    $object->addChild( $xml_doc->createAttribute('id',$subject->id) );
    $object->addChild( $xml_doc->createAttribute('generated-at',$time) );
    $object->addChild( $xml_doc->createAttribute('name',$subject->name) );
    $object->addChild( $xml_doc->createAttribute('type', $subject->class));
    $object->addChild( $self->get_alignment_summary_node() );
    $object->addChild( $self->get_coverage_summary_node() );
    return $xml_doc->toString(1);
}

sub get_alignment_summary_node {
    my $self = shift;
    my $xml_doc = $self->_xml_doc;
    my @models = $self->subject->models;
    my $as_node = $xml_doc->createElement('alignment-summary');
    for my $model (@models) {
        my $build = $model->last_succeeded_build;
        if ($build) {
            my $model_node = $as_node->addChild( $xml_doc->createElement('model') );
            $model_node->addChild( $xml_doc->createAttribute('id',$model->id));
            $model_node->addChild( $xml_doc->createAttribute('subject_name',$model->subject_name));
            my $alignment_summary_hash_ref = $build->alignment_summary_hash_ref;
            for my $key (keys %{$alignment_summary_hash_ref->{0}}) {
                my $key_node = $model_node->addChild( $xml_doc->createElement($key) );
                $key_node->addChild( $xml_doc->createTextNode( $alignment_summary_hash_ref->{0}->{$key} ) );
            }
        }
    }
    return $as_node;
}

sub get_coverage_summary_node {
    my $self = shift;
    my $xml_doc = $self->_xml_doc;
    my @models = $self->subject->models;
    my $cs_node = $xml_doc->createElement('coverage-summary');
    my @min_depths;
    for my $model (@models) {
        my $build = $model->last_succeeded_build;
        if ($build) {
            unless (@min_depths) {
                @min_depths = sort{ $a <=> $b } @{$build->minimum_depths_array_ref};
                for my $min_depth (@min_depths) {
                    my $header_node = $cs_node->addChild( $xml_doc->createElement('minimum_depth_header') );
                    $header_node->addChild( $xml_doc->createAttribute('value',$min_depth) );
                }
            } else {
                my @other_min_depths = sort{ $a <=> $b } @{$build->minimum_depths_array_ref};
                unless (scalar(@min_depths) == scalar(@other_min_depths)) {
                    die('Model '. $model->name .' has '. scalar(@other_min_depths) .' minimum_depth filters expecting '. scalar(@min_depths) .' minimum_depth filters');
                }
                for (my $i = 0; $i < scalar(@min_depths); $i++) {
                    my $expected_min_depth = $min_depths[$i];
                    my $other_min_depth = $other_min_depths[$i];
                    unless ($expected_min_depth == $other_min_depth) {
                        die('Model '. $model->name .' has '. $other_min_depth .' minimum_depth filter expecting '. $expected_min_depth .' minimum_depth filter');
                    }
                }
            }
            my $model_node = $cs_node->addChild( $xml_doc->createElement('model') );
            $model_node->addChild( $xml_doc->createAttribute('id',$model->id));
            $model_node->addChild( $xml_doc->createAttribute('subject_name',$model->subject_name));
            my $coverage_stats_summary_hash_ref = $build->coverage_stats_summary_hash_ref;
            for my $min_depth (keys %{$coverage_stats_summary_hash_ref->{0}}) {
                my $min_depth_node = $model_node->addChild( $xml_doc->createElement('minimum_depth') );
                $min_depth_node->addChild( $xml_doc->createAttribute('value',$min_depth) );
                for my $key (keys %{$coverage_stats_summary_hash_ref->{0}->{$min_depth}}) {
                    my $key_node = $min_depth_node->addChild( $xml_doc->createElement($key) );
                    $key_node->addChild( $xml_doc->createTextNode( $coverage_stats_summary_hash_ref->{0}->{$min_depth}->{$key} ) );
                }
            }
        }
    }
    return $cs_node;
}








