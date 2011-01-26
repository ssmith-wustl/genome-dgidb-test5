package Genome::Model::Tools::DetectVariants2::Dispatcher;

use strict;
use warnings;

use Clone qw/clone/;
use Data::Dumper;
use JSON;
use Genome;
use Workflow;

class Genome::Model::Tools::DetectVariants2::Dispatcher {
    is => ['Genome::Model::Tools::DetectVariants2::Base'],
    doc => 'This tool is used to handle delegating variant detection to one or more specified tools and filtering and/or combining the results',
};

sub help_brief {
    "A dispatcher for variant detectors.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants2 dispatcher ...
EOS
} #TODO Fill in this synopsis with a few examples

sub help_detail {
    return <<EOS 
A variant detector(s) specified under snv-detection-strategy, indel-detection-strategy, or sv-detection-strategy must have a corresponding module under `gmt detect-variants`.
EOS
}

sub plan {
    my $self = shift;

    my $trees = {};
    my $plan = {};

    for my $variant_type (@{ $self->variant_types }) {
        my $name_property = $variant_type . '_detection_strategy';
        my $strategy = $self->$name_property;
        if($strategy) {
            my $tree = $strategy->tree;
            die "Failed to get detector tree for $name_property" if !defined $tree;
            $trees->{$variant_type} = $tree;
            $self->build_detector_list($trees->{$variant_type}, $plan, $variant_type);
        }
    } 

    return ($trees, $plan);
}

sub _detect_variants {
    my $self = shift;

    my ($trees, $plan) = $self->plan;

    my $workflow = $self->generate_workflow($trees, $plan);

    my @errors = $workflow->validate;

    if (@errors) {
        $self->error_message(@errors);
        die "Errors validating workflow\n";
    }

    die "Not implemented yet, awaiting workflow code. The strategy looks like: " . Dumper($trees) . "The condensed job map looks like: " . Dumper($plan);

    $workflow->execute;
}

sub calculate_detector_output_directory {
    my $self = shift;
    my ($detector, $version, $param_list) = @_;
    
    my $subdirectory = join('-', $detector, $version, $param_list);
    
    return $self->output_directory . '/' . Genome::Utility::Text::sanitize_string_for_filesystem($subdirectory);
}

sub parse_detection_strategy {
    my $self = shift;
    my $string = shift;

    return unless $string;
    
    my $parser = $self->parser;
    
    my $result = $parser->startrule($string);
    
    unless($result) {
        $self->error_message('Failed to interpret detector string from ' . $string);
        die($self->error_message);
    }
    
    return $result;
}

sub is_valid_detector {
    # TODO: check version, possibly params
    my ($self, $detector_class, $detector_version) = @_;
    
    return if $detector_class eq $self->class; #Don't nest the dispatcher!
    
    my $detector_class_base = 'Genome::Model::Tools::DetectVariants';
    return $detector_class->isa($detector_class_base);
}

sub merge_filters {
    my ($a, $b) = @_;
    my %filters = map { to_json($_) => $_ } (@$a, @$b);
    return [values %filters];
}

# return value is a hash like:
# { samtools => { r453 => {snv => ['']}}, 'var-scan' => { '' => { snv => ['']} }, maq => { '0.7.1' => { snv => ['a'] } }}
sub build_detector_list {
    my $self = shift;
    my ($detector_tree, $detector_list, $detector_type) = @_;
    
    #Just recursively keep looking for detectors
    my $branch_case = sub {
        my $self = shift;
        my ($combination, $subtrees, $branch_case, $leaf_case, $detector_list, $detector_type) = @_;
        
        for my $subtree (@$subtrees) {
            $self->walk_tree($subtree, $branch_case, $leaf_case, $detector_list, $detector_type);
        }
        
        return $detector_list;
    };
    
    #We found the detector we're looking for
    my $leaf_case = sub {
        my $self = shift;
        my ($detector, $branch_case, $leaf_case, $detector_list, $detector_type) = @_;

        my $name = $detector->{name};
        my $version = $detector->{version};
        my $params = $detector->{params};
        my $d = clone($detector);
        
        #Do not push duplicate entries
        if (exists($detector_list->{$name}{$version}{$detector_type})) {
            my @matching_params = grep {$_->{params} eq $params} @{$detector_list->{$name}{$version}{$detector_type}};
            if (!@matching_params) {
                push @{ $detector_list->{$name}{$version}{$detector_type} }, $d;
            } else {
                my $m = shift @matching_params;
                my $existing_filters = $m->{filters};
                my $merged_filters = merge_filters($m->{filters}, $d->{filters});
                if (scalar @$merged_filters != scalar @$existing_filters) {
                    $m->{filters} = $merged_filters;
                }
            }
        } else {
            $detector_list->{$name}{$version}{$detector_type} = [$d];
        }
        
        return $detector_list;
    };
    
    return $self->walk_tree($detector_tree, $branch_case, $leaf_case, $detector_list, $detector_type);
}

#A generic walk of the tree structure produced by the parser--takes two subs $branch_case and $leaf_case to handle the specific logic of the step
sub walk_tree {
    my $self = shift;
    my ($detector_tree, $branch_case, $leaf_case, @params) = @_;
    
    unless($detector_tree) {
        $self->error_message('No parsed detector tree provided.');
        die($self->error_message);
    }
    
    my @keys = keys %$detector_tree;
    
    #There should always be exactly one outer rule (or detector)
    unless(scalar @keys eq 1) {
        $self->error_message('Unexpected data structure encountered!  There were ' . scalar(@keys) . ' keys');
        die($self->error_message . "\nTree: " . Dumper($detector_tree));
    }
    
    my $key = $keys[0];
    
    #Case One:  We're somewhere in the middle of the data-structure--we need to combine some results
    if($key eq 'intersect' or $key eq 'union') {
        my $value = $detector_tree->{$key};
        
        unless(ref $value eq 'ARRAY') {
            $self->error_message('Unexpected data structure encountered! I really wanted an ARRAY, not ' . (ref($value)||$value) );
            die($self->error_message);
        }
        
        return $branch_case->($self, $key, $value, $branch_case, $leaf_case, @params);
    } elsif($key eq 'detector') {
        my $value = $detector_tree->{$key};

        unless(ref $value eq 'HASH') {
            $self->error_message('Unexpected data structure encountered! I really wanted a HASH, not ' . (ref($value)||$value) );
            die($self->error_message);
        }
        return $leaf_case->($self, $value, $branch_case, $leaf_case, @params);
    } else {
        $self->error_message("Unknown key in detector hash: $key");
    }
    #Case Two: Otherwise the key should be the a detector specification hash, 
}

sub generate_workflow {
    my $self = shift;
    my ($trees, $plan) = @_;

    my $workflow_model = Workflow::Model->create(
        name => 'Somatic Variation Pipeline',
        input_properties => [
            'reference_sequence_input',
            'aligned_reads_input',
            'control_aligned_reads_input',
            'output_directory',
        ],
        output_properties => [
            'result', #TODO should anything go here? For now just have an output per detector, below
        ],
    );

    # TODO do I need to iterate through the original tree instead of the condensed map?
    # Make an operation for each detector
    for my $detector (keys %$plan) {
        # Get the hashref that contains all versions to be run for a detector
        my $detector_hash = $plan->{$detector};
        $workflow_model = $self->generate_workflow_operation($detector_hash, $workflow_model);
    }


    # TODO filter each detector if any are defined

    # TODO union and intersect each post-filtering detector output if necessary

    $workflow_model->as_png("/gscuser/gsanders/test.png"); # TODO remove this, or put a copy of the as_xml in the output dir maybe

    return $workflow_model;
}

# TODO rename this, or make it return the operations to be added instead of adding them itself
sub generate_workflow_operation { 
    my $self = shift;
    my $detector_hash = shift;
    my $workflow_model = shift;

    for my $version (keys %$detector_hash) {
        # Get the hashref that contains all the variant types to be run for a given detector version
        my $version_hash = $detector_hash->{$version};

        my %param_hash;
        my ($class,$name, $version);
        for my $variant_type (keys %$version_hash) {
            my @instances_for_variant_type = @{$version_hash->{$variant_type}};
            for my $instance (@instances_for_variant_type) {
                my $params = $instance->{params};
                $param_hash{$variant_type."_params"} = $params;
                $class = $instance->{class};
                $name = $instance->{name};
                $version = $instance->{version};
                my $output_directory = $self->calculate_detector_output_directory($name, $version, $params);

                # Make the operation
                my $operation = $workflow_model->add_operation(
                    name => $name,
                    operation_type => Workflow::OperationType::Command->get($class),
                );

                # TODO Unhardcode this list of properties
                # Add the required links that are the same for every variant detector
                for my $property ( 'reference_sequence_input', 'aligned_reads_input', 'control_aligned_reads_input') {
                    $workflow_model->add_link(
                        left_operation => $workflow_model->get_input_connector,
                        left_property => $property,
                        right_operation => $operation,
                        right_property => $property,
                    );
                }

                # add the properties this variant detector needs (version, params,output dir) to the input connector
                my $properties_for_detector = $self->properties_for_detector($name, $version, $params);
                my @input_connector_properties = map { $properties_for_detector->{$_} } (keys %$properties_for_detector);
                my $input_connector = $workflow_model->get_input_connector;
                my $inputs = $input_connector->operation_type->output_properties;
                push @{$inputs}, @input_connector_properties;
                $input_connector->operation_type->output_properties($inputs);

                # connect those properties from the input connector to this operation
                for my $property (keys %$properties_for_detector) {
                    $workflow_model->add_link(
                        left_operation => $workflow_model->get_input_connector,
                        left_property => $properties_for_detector->{$property},
                        right_operation => $operation,
                        right_property => $property,
                    );
                }

                #TODO Generate an output property per detector

                #TODO Connect each detector's output to the output connector
            }
        }
    }

    return $workflow_model;
}

sub properties_for_detector {
    my $self = shift;
    my ($name, $version, $params) = @_;
    $params ||= "";

    # This hashref will contain property_name_for_detector => unique_name_for_input_connector
    my $property_map;
    for my $property ("version", "snv_params", "indel_params", "sv_params", "output_directory") {
        $property_map->{$property} = "$name-$version-$params" . "_$property";
    }

    return $property_map;
}

1;
