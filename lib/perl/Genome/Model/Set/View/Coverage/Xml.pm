package Genome::Model::Set::View::Coverage::Xml;

use strict;
use warnings;

class Genome::Model::Set::View::Coverage::Xml {
    is => 'UR::Object::View::Default::Xml',
    has_constant => [
        perspective => 'coverage',
    ],
};

sub all_subject_classes {
    my $self = shift;
    my @classes = $self->SUPER::all_subject_classes;

    #If more sophisticated handling is required,
    #can substitute the particular classes of model
    #returned by $self->members.  This is quick and
    #sufficient for now.
    unless(grep($_->isa('Genome::Model'), @classes)) {
        push @classes, 'Genome::Model';
    }

    return @classes;
}

sub members {
    my $self = shift;

    my $set = $self->subject;

    my @members = $set->members;

    return @members;
}

sub _generate_content {
    my $self = shift;
    my $subject = $self->subject();

    #preload data for efficiency
    my @members = $self->members;
    my @model_ids = map($_->id, @members);
    my @idas = Genome::Model::InstrumentDataAssignment->get(model_id => \@model_ids);
    my @builds = Genome::Model::Build->get(model_id => \@model_ids);
    my @events = Genome::Model::Event->get(build_id => [map($_->id, @builds)]);

    my $xml_doc = XML::LibXML->createDocument();
    $self->_xml_doc($xml_doc);

    my $object = $xml_doc->createElement('object');
    $xml_doc->setDocumentElement($object);
    my $time = UR::Time->now();
    $object->addChild( $xml_doc->createAttribute('id',$subject->id) );
    $object->addChild( $xml_doc->createAttribute('generated-at',$time) );

    my $name;
    if($subject->can('name')) {
        $name = $subject->name;
    } elsif($subject->can('rule_display')) {
        $name = $subject->rule_display;
        $name =~ s/^UR::BoolExpr=\([\w:]+/Set: /;
        $name =~ s/_/-/g;
        $name =~ s/ =>/:/g;
        $name =~ s/"//g;
        $name =~ s/\)$//;
        $name =~ s/([\w\d]),([\w\d])/$1, $2/g;
    } else {
        $name = $subject->id;
    }

    $object->addChild( $xml_doc->createAttribute('display_name',$name) );
    $object->addChild( $xml_doc->createAttribute('type', $subject->class));
    $object->addChild( $self->get_enrichment_factor_node() );
    $object->addChild( $self->get_alignment_summary_node() );
    $object->addChild( $self->get_coverage_summary_node() );

    return $xml_doc->toString(1);
}

sub get_last_succeeded_coverage_stats_build_from_model {
    my $self = shift;
    my $model = shift;
    my @sorted_builds = sort { $b->id <=> $a->id } $model->builds();
    for my $build (@sorted_builds) {
        my @events = $build->the_events;
        my @coverage_stats_events = grep { $_->class eq 'Genome::Model::Event::Build::ReferenceAlignment::CoverageStats' } @events;
        if (scalar(@coverage_stats_events) == 1) {
            my $coverage_stats_event = $coverage_stats_events[0];
            if ($coverage_stats_event->event_status eq 'Succeeded') {
                return $build;
            }
        }
    }
    return;
}

sub get_enrichment_factor_node {
    my $self = shift;
    my $xml_doc = $self->_xml_doc;
    my @models = $self->members;

    my @included_models;
    my $ef_node = $xml_doc->createElement('enrichment-factor');
    for my $model (@models) {
        my $build = $self->get_last_succeeded_coverage_stats_build_from_model($model);

        if ($build) {
            push(@included_models, $model);
            my $model_node = $ef_node->addChild( $xml_doc->createElement('model') );
            $model_node->addChild( $xml_doc->createAttribute('id', $model->id) );
            $model_node->addChild( $xml_doc->createAttribute('subject_name', $model->subject_name) );
            $model_node->addChild( $xml_doc->createAttribute('model_name',$model->name));

            my @idata = $model->instrument_data_assignments;

            $model_node->addChild( $xml_doc->createAttribute('lane_count', scalar(@idata)));

            # get BED file
            my $bedf;
            my $refcovd = $build->data_directory . "/reference_coverage";
            opendir(my $refcovdh, $refcovd) or die "Could not open reference coverage directory at $refcovd";

            while (my $file = readdir($refcovdh)) {
                if ($file =~ /.*.bed/) { $bedf = $refcovd . "/" . $file; }
            }

            # calculate target_total_bp
            my $target_total_bp;

            open(my $bedfh, "<", $bedf) or die "Could not open BED file at $bedf";

            while (<$bedfh>) {
                chomp;
                my @f      = split (/\t/, $_);
                my $start  = $f[1];
                my $stop   = $f[2];
                my $length = ($stop - $start);
                $target_total_bp += $length;
            }

            # calculate genome_total_bp from reference sequence seqdict.sam
            my $genome_total_bp;
            my $seqdictf = $build->model->reference_sequence_build->data_directory . "/seqdict/seqdict.sam";

            open(my $seqdictfh, "<", $seqdictf) or die "Could not open seqdict at $seqdictf";

            while (<$seqdictfh>) {
                chomp;
                unless($_ =~ /$@HD/) { # skip the header row
                    my @f = split(/\t/, $_);
                    my $ln = $f[2];
                    $ln =~ s/LN://;
                    $genome_total_bp += $ln;
                }
            }

            # get wingspan 0 alignment metrics
            my $ws_zero = $build->alignment_summary_hash_ref->{'0'};

            # calculate enrichment factor!
            my $myEF = Genome::Model::Tools::TechD::CaptureEnrichmentFactor->execute(
                capture_unique_bp_on_target    => $ws_zero->{'unique_target_aligned_bp'},
                capture_duplicate_bp_on_target => $ws_zero->{'duplicate_target_aligned_bp'},
                capture_total_bp               => $ws_zero->{'total_aligned_bp'} + $ws_zero->{'total_unaligned_bp'},
                target_total_bp                => $target_total_bp,
                genome_total_bp                => $genome_total_bp
            );

            my $theoretical_max_enrichment_factor = 0;
            my $unique_on_target_enrichment_factor = 0;
            my $total_on_target_enrichment_factor = 0;

            if ($myEF) {
                $theoretical_max_enrichment_factor  = $myEF->theoretical_max_enrichment_factor();
                $unique_on_target_enrichment_factor = $myEF->unique_on_target_enrichment_factor();
                $total_on_target_enrichment_factor  = $myEF->total_on_target_enrichment_factor();
            }

            my $uotef_node = $model_node->addChild( $xml_doc->createElement('unique_on_target_enrichment_factor') );
            $uotef_node->addChild( $xml_doc->createTextNode( $unique_on_target_enrichment_factor ) );

            my $totef_node = $model_node->addChild( $xml_doc->createElement('total_on_target_enrichment_factor') );
            $totef_node->addChild( $xml_doc->createTextNode( $total_on_target_enrichment_factor ) );

            my $tmef_node = $model_node->addChild( $xml_doc->createElement('theoretical_max_enrichment_factor') );
            $tmef_node->addChild( $xml_doc->createTextNode( $theoretical_max_enrichment_factor ) );

        }
    }

    return $ef_node;
}


sub get_alignment_summary_node {
    my $self = shift;
    my $xml_doc = $self->_xml_doc;
    my @models = $self->members;
    my @included_models;
    my $as_node = $xml_doc->createElement('alignment-summary');
    for my $model (@models) {
        my $build = $self->get_last_succeeded_coverage_stats_build_from_model($model);
        if ($build) {
            push(@included_models, $model);
            my $model_node = $as_node->addChild( $xml_doc->createElement('model') );
            $model_node->addChild( $xml_doc->createAttribute('id',$model->id));
            $model_node->addChild( $xml_doc->createAttribute('subject_name',$model->subject_name));
            $model_node->addChild( $xml_doc->createAttribute('model_name',$model->name));

            my @idata = $model->instrument_data_assignments;

            $model_node->addChild( $xml_doc->createAttribute('lane_count', scalar(@idata)) );

            my $alignment_summary_hash_ref = $build->alignment_summary_hash_ref;
            for my $ws_key (keys %{$alignment_summary_hash_ref}) {
                my $ws_node = $model_node->addChild( $xml_doc->createElement('wingspan') );
                $ws_node->addChild( $xml_doc->createAttribute('size', $ws_key) );
                for my $param_key (keys %{$alignment_summary_hash_ref->{$ws_key}}) {
                    my $key_node = $ws_node->addChild( $xml_doc->createElement($param_key) );
                    $key_node->addChild( $xml_doc->createTextNode( $alignment_summary_hash_ref->{$ws_key}->{$param_key} ) );
                }
            }
        }
    }

    return $as_node;
}

sub get_coverage_summary_node {
    my $self = shift;
    my $xml_doc = $self->_xml_doc;
    my @models = $self->members;
    my @included_models;
    my $cs_node = $xml_doc->createElement('coverage-summary');
    my @min_depths;
    for my $model (@models) {
        my $build = $self->get_last_succeeded_coverage_stats_build_from_model($model);
        if ($build) {
            push(@included_models, $model);
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
            $model_node->addChild( $xml_doc->createAttribute('model_name',$model->name));

            my @idata = $model->instrument_data_assignments;

            $model_node->addChild( $xml_doc->createAttribute('lane_count', scalar(@idata)) );

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

1;
