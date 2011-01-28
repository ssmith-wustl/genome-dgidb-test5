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
    has_optional => [
        _workflow_inputs => {
            doc => "Inputs to pass into the workflow when executing",
        },
    ],
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

# FIXME this is a hack to get things to run until I decide how to implement this in the dispatcher
# In the first version of the dispatcher... this was not implemented if there were unions or intersections... and if there were none of those it just grabbed the inputs from the only variant detector run and made it its own
sub _generate_standard_files {
    return 1;
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

    my @stored_properties = @{$self->_workflow_inputs};

    $workflow->execute(
        input => {
            aligned_reads_input => $self->aligned_reads_input,
            control_aligned_reads_input => $self->control_aligned_reads_input,
            reference_sequence_input => $self->reference_sequence_input,
            output_directory => $self->output_directory,
            @stored_properties, # TODO test for multiple detectors
        }   
    );

    $workflow->wait;

    return 1;
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

# TODO this may not need to be here, if we validate inside strategy
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

    # TODO remove this, or put a copy of the as_xml in the output dir maybe
    #my $xml = $workflow_model->save_to_xml;

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

        my ($class,$name, $version);
        for my $variant_type (keys %$version_hash) {
            my @instances_for_variant_type = @{$version_hash->{$variant_type}};
            for my $instance (@instances_for_variant_type) {
                my $params = $instance->{params};
                $class = $instance->{class};
                $name = $instance->{name};
                $version = $instance->{version};

                # Make the operation
                my $operation = $workflow_model->add_operation(
                    name => "$variant_type $name $version $params",
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
                my $properties_for_detector = $self->properties_for_detector($variant_type, $name, $version, $params);
                my @new_input_connector_properties = map { $properties_for_detector->{$_} } (keys %$properties_for_detector);
                my $input_connector = $workflow_model->get_input_connector;
                my $input_connector_properties = $input_connector->operation_type->output_properties;
                push @{$input_connector_properties}, @new_input_connector_properties;
                $input_connector->operation_type->output_properties($input_connector_properties);

                # connect those properties from the input connector to this operation
                for my $property (keys %$properties_for_detector) {
                    my $input_connector_property_name = $properties_for_detector->{$property};
                    $workflow_model->add_link(
                        left_operation => $workflow_model->get_input_connector,
                        left_property => $input_connector_property_name,
                        right_operation => $operation,
                        right_property => $property,
                    );
                }

                # Generate an output property for the detector
                my $output_connector = $workflow_model->get_output_connector;
                my $output_connector_properties = $output_connector->operation_type->input_properties;
                my $new_output_connector_property = $name . "_" . $version . "_" . $params . "_output";
                push @{$output_connector_properties}, $new_output_connector_property;
                $output_connector->operation_type->input_properties($output_connector_properties);

                #Connect each detector's output to the output connector
                $workflow_model->add_link(
                    left_operation => $operation,
                    left_property => "output_directory",
                    right_operation => $workflow_model->get_output_connector,
                    right_property => $new_output_connector_property
                );
            }
        }
    }

    return $workflow_model;
}

# TODO rename or break up this sub
# Currently this:
# 1) Calculates the (unique, hopefully) names of the 3 properties the input connector needs in order to pass to the detect variants module
# 2) Adds a hash of input_connector_property => value to the class so it can be stuffed into execute when run
# 3) Returns a mapping for properties from detect_variants_param => input_connector_param_name
sub properties_for_detector {
    my $self = shift;
    my ($variant_type, $name, $version, $params) = @_;
    $params ||= "";

    # This hashref will contain property_name_for_detector => unique_name_for_input_connector
    my $appropriate_params = "$variant_type" . "_params";
    my $property_map;
    for my $property ("version", $appropriate_params, "output_directory") {
        $property_map->{$property} = $name . "_" . $version . "_" . $params . "_" . $property;
    }

    my $output_directory = $self->calculate_detector_output_directory($name, $version, $params);

    # Store these params for passing to the workflow when we execute it
    # We will only have one variant type of params, ignore the old API
    my %inputs_to_store;
    $inputs_to_store{$property_map->{version}} = $version;
    $inputs_to_store{$property_map->{$appropriate_params}} = $params;
    $inputs_to_store{$property_map->{output_directory}} = $output_directory;

    # Try to account for previous detect variants properties
    my @stored_properties;
    if ($self->_workflow_inputs) {
        @stored_properties = $self->_workflow_inputs;
    }
    push @stored_properties, %inputs_to_store;
    $self->_workflow_inputs(\@stored_properties);

    return $property_map;
}

1;
