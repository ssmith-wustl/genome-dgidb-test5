package Genome::Model::Tools::DetectVariants2::Dispatcher;

use strict;
use warnings;

use Clone qw/clone/;
use Data::Dumper;
use JSON;
use Genome;
use Workflow;
use Workflow::Simple;
use File::Basename;

class Genome::Model::Tools::DetectVariants2::Dispatcher {
    is => ['Genome::Model::Tools::DetectVariants2::Base'],
    doc => 'This tool is used to handle delegating variant detection to one or more specified tools and filtering and/or combining the results',
    has_optional => [
        _snv_hq_output_file => {
            is => 'String',
            is_output => 1,
            doc => 'High Quality SNV output file',
        },
        _indel_hq_output_file => {
            is => 'String',
            is_output => 1,
            doc => 'High Quality indel output file',
        },
        _sv_hq_output_file => {
            is => 'String',
            is_output => 1,
            doc => 'High Quality SV output file',
        },
        _cnv_hq_output_file => {
            is => 'String',
            is_output => 1,
            doc => 'High Quality CNV output file',
        },
        snv_detection_strategy => {
            is => "Genome::Model::Tools::DetectVariants2::Strategy",
            doc => 'The variant detector strategy to use for finding SNVs',
        },
        indel_detection_strategy => {
            is => "Genome::Model::Tools::DetectVariants2::Strategy",
            doc => 'The variant detector strategy to use for finding indels',
        },
        sv_detection_strategy => {
            is => "Genome::Model::Tools::DetectVariants2::Strategy",
            doc => 'The variant detector strategy to use for finding SVs',
        },
        cnv_detection_strategy => {
            is => "Genome::Model::Tools::DetectVariants2::Strategy",
            doc => 'The variant detector strategy to use for finding copy number variation',
        },

    ],
    has_constant => [
        variant_types => {
            is => 'ARRAY',
            value => [('snv', 'indel', 'sv', 'cnv')],
        },
    ],
    has_transient_optional => [
        _workflow_result => {
            doc => 'hand the workflow result down to the _promote_staged_data dir',
        },
        _workflow_inputs => {
            doc => "Inputs to pass into the workflow when executing",
        },
        _workflow_links => {
            doc => "A hash of the detector/filter subgroups",
        },
        _workflow_model => {
            doc => "This is the workflow model",
        },
        _expected_output_directories => {
            doc => "This is a hash (by variant type) of lists of all detector, filter, and combine operation output directories",
        },
    ],
    has_param => [
        lsf_queue => {
            default_value => 'workflow'
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
} #TODO Fill in this synopsis with a few examples. Possible examples are shown in the processing profile create help

sub help_detail {
    return <<EOS 
A variant detector(s) specified under snv-detection-strategy, indel-detection-strategy, or sv-detection-strategy must have a corresponding module under `gmt detect-variants`.
EOS
}

# Validate all strategies specified upon object creation
sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);

    for my $variant_type (@{ $self->variant_types }) {
        my $name_property = $variant_type . '_detection_strategy';
        my $strategy = $self->$name_property;
        if($strategy and !ref $strategy) {
            $self->$name_property(Genome::Model::Tools::DetectVariants2::Strategy->get($strategy));
        }
        if ($strategy) {
            die if $self->$name_property->__errors__; # TODO make this a more descriptive error
        }
    }

    return $self;
}

# Takes all of the strategies specified and uses G::M::T::DV2::Strategy to turn them into a traversable hash containing the complete action plan to detect variants
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

# Detect variants using all input detection strategies. Generates a workflow to do all of the work and executes it, storing the result in $self->_workflow_result
sub _detect_variants {
    my $self = shift;

    unless ($self->snv_detection_strategy || $self->indel_detection_strategy || $self->sv_detection_strategy || $self->cnv_detection_strategy) {
        $self->error_message("Please provide one or more of: snv_detection_strategy, indel_detection_strategy, sv_detection_strategy, or cnv_detection_strategy");
        die $self->error_message;
    }

    my ($trees, $plan) = $self->plan;
    my $workflow = $self->generate_workflow($trees, $plan);

    my @errors = $workflow->validate;

    if (@errors) {
        $self->error_message(@errors);
        die "Errors validating workflow\n";
    }
    my $input;  
    my $workflow_inputs = $self->_workflow_inputs;
    map { $input->{$_} = $workflow_inputs->{$_}->{value}} keys(%{$workflow_inputs});
    $input->{aligned_reads_input}= $self->aligned_reads_input;
    $input->{control_aligned_reads_input} = $self->control_aligned_reads_input;
    $input->{reference_build_id} = $self->reference_build_id;
    $input->{output_directory} = $self->_temp_staging_directory;
   
    $self->_dump_workflow($workflow);
    $self->_dump_dv_cmd;

    $self->status_message("Now launching the dispatcher workflow.");
    ## Worklow launches here
    my $result = Workflow::Simple::run_workflow_lsf( $workflow, %{$input});

    unless($result){
        $self->error_message( join("\n", map($_->name . ': ' . $_->error, @Workflow::Simple::ERROR)) );
        die $self->error_message("Workflow did not return correctly.");
    }
    $self->_workflow_result($result);

    return 1;
}

# Dump the workflow generated to xml in the output directory
sub _dump_workflow {
    my $self = shift;
    my $workflow = shift;
    my $xml = $workflow->save_to_xml;
    my $xml_location = $self->output_directory."/workflow.xml";
    $self->_rotate_old_files($xml_location); #clean up any previous runs
    my $xml_file = Genome::Sys->open_file_for_writing($xml_location);
    print $xml_file $xml;
    $xml_file->close;
    #$workflow->as_png($self->output_directory."/workflow.png"); #currently commented out because blades do not all have the "dot" library to use graphviz
}

sub _dump_dv_cmd {
    my $self = shift;
    my $cmd = join(" ",@INC)."\n===============================================\n";
    $cmd  =      "gmt detect-variants2 dispatcher --output-directory " .$self->output_directory
                ." --aligned-reads-input ".$self->aligned_reads_input
                ." --control-aligned-reads-input ".$self->control_aligned_reads_input
                ." --reference-build-id ".$self->reference_build_id;
    for my $var ('snv','sv','indel'){
        my $strat = $var."_detection_strategy";
        if(defined($self->$strat)){
            $cmd .= " --".$strat." \'".$self->$strat->id."\'";
        }
    }

    my $dispatcher_cmd_file = $self->output_directory."/dispatcher.cmd";
    $self->_rotate_old_files($dispatcher_cmd_file); #clean up any previous runs

    my $dfh = Genome::Sys->open_file_for_writing($dispatcher_cmd_file);
    print $dfh $cmd."\n";
    $dfh->close;
    return 1;
}

sub get_relative_path_to_output_directory {
    my $self = shift;
    my $full_path = shift;
    my $relative_path = $full_path; 
    my $temp_path = $self->_temp_staging_directory;
    $relative_path =~ s/$temp_path\/?//;
    return $relative_path;
}

sub calculate_operation_output_directory {
    my $self = shift;
    my ($base_directory, $name, $version, $param_list) = @_;
    my $subdirectory = join('-', $name, $version, $param_list);
    
    return $base_directory . '/' . Genome::Utility::Text::sanitize_string_for_filesystem($subdirectory);
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

sub merge_filters {
    my ($a, $b) = @_;
    my %filters = map { to_json($_) => $_ } (@$a, @$b);
    return [values %filters];
}

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
#adding 
sub combine_results {
    my $self = shift;
    my ($detector_tree, $detector_type, $versions, $params) = @_;
    
    #Need to combine by intersection or union
    my $branch_case = sub {
        my $self = shift;
        my ($combination, $subtrees, $branch_case, $leaf_case, $detector_type, $versions, $params) = @_;
        
        $self->error_message('Support for unions and intersections is not yet available.');
        die($self->error_message);
    };
    
    #A single detector--just find the relevant file and pass it back
    my $leaf_case = sub {
        my $self = shift;
        my ($detector_name, $index, $branch_case, $leaf_case, $detector_type, $versions, $params) = @_;
        
        #TODO When we enable the boolean expressions, the directory name will need to take into account parameters as well
        my $command_output_directory = $self->calculate_detector_output_directory($detector_name, $versions->[$index], '');
        
        #Somewhere down the line filtering should perhaps be separated from the actual detection?
        my $output_file_property = $detector_type . '_output';
        my $filtered_output_file_property = 'filtered_' . $output_file_property;
        
        my $_temp_staging_directory = $self->_temp_staging_directory;
        my $output_file = $self->$output_file_property;
        my $filtered_output_file = $self->$filtered_output_file_property;
        
        $output_file =~ s/$_temp_staging_directory/$command_output_directory/;
        $filtered_output_file =~ s/$_temp_staging_directory/$command_output_directory/;
        
        return [$output_file, $filtered_output_file];
    };
    
    return $self->walk_tree($detector_tree, $branch_case, $leaf_case, $detector_type, $versions, $params);
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

# Create the outer workflow and then call methods to generate the individual operations
sub generate_workflow {
    my $self = shift;
    my ($trees, $plan) = @_;
    my @output_properties;

    push @output_properties, 'snv_output_directory' if defined ($self->snv_detection_strategy);
    push @output_properties, 'sv_output_directory' if defined ($self->sv_detection_strategy);
    push @output_properties, 'indel_output_directory' if defined ($self->indel_detection_strategy);
    push @output_properties, 'cnv_output_directory' if defined ($self->cnv_detection_strategy);

    my $workflow_model = Workflow::Model->create(
        name => 'Somatic Variation Pipeline',
        input_properties => [
            'reference_build_id',
            'aligned_reads_input',
            'control_aligned_reads_input',
            'output_directory',
        ],
        output_properties => [
            @output_properties
        ],
    );
    $workflow_model->log_dir($self->output_directory);
    for my $detector (keys %$plan) {
        # Get the hashref that contains all versions to be run for a detector
        my $detector_hash = $plan->{$detector};
        $workflow_model = $self->add_detectors_and_filters($detector_hash, $workflow_model);
    }
    my @root = keys( %{ $trees} );
    for my $variant_type (@root){
        my ($key) = keys(%{$trees->{$variant_type}});
        my $end_result = $self->link_operations( $trees->{$variant_type}, $variant_type );

        #this is a hack that allows the innards of our workflow composition to re-use
        # detector output. This should be replaced by something less hackish.
        if($end_result =~ m/unfiltered$/){
            $end_result =~ s/unfiltered$//;
        }
        my $workflow_links = $self->_workflow_links;
        $workflow_model = $self->_workflow_model;

        # this links in the very last operation in workflow, as determined by link_operations,
        # and connects it to the proper output connector.
        my $last_operation_name = $workflow_links->{$end_result."_output_directory"}->{last_operation};
        my $last_operation = $workflow_links->{$last_operation_name."_output_directory"}->{right_operation};
        $workflow_model->add_link(
            left_operation => $last_operation,
            left_property => "output_directory",
            right_operation => $workflow_model->get_output_connector,
            right_property => $variant_type."_output_directory",
        );
#TODO Once combine functions have results, return the result as output
#        $workflow_model->add_link(
#            left_operation => $last_operation,
#            left_property => 'result_id',
#            right_operation => $workflow_mode->get_output_connector,
#            right_property => $variant_type."_result_id",
#        );
    }
    return $workflow_model;
}

# This sub functions in a recursive manner on the detection strategies. It is given a hash of the
# entire strategy, and it breaks off the next level of the strategy and calls itself on those. It then
# receives operation names from those lower level operations, and creates the current operation, linking
# the lower level ops into it.  The anchor case is when a detector is reached. Then recursion stops
# and the function returns the unqiue detector name.

sub link_operations { 
    my $self = shift;

    my $tree = shift;
    my $variant_type = shift;

    my ($key) = keys( %{$tree} );
    my @incoming_links;
    my $unique_combine_name;
    
    # This is a leaf node, cease recursion and return the unique detector name
    # If the detector has no filters, tack on "unfiltered" to the name. This is 
    # a hack in order to allow smarter shortcutting for strategies which have 
    # multiple instances of the same detector, but filtered differently
    if($key eq 'detector'){
        my $name =  $self->get_unique_detector_name($tree->{$key}, $variant_type);
        my $filters = scalar(@{$tree->{$key}->{filters}});
        unless($filters){
            $name .= 'unfiltered';
        }
        return $name;
    }

    # We expect to see an intersect or union operation here, if there are more or less than 2 keys, asplode
    my @inputs = @{$tree->{$key}};
    unless(scalar(@inputs)==2){
        $self->error_message("attempting to build a workflow, but we have found an operation ( ".$key." ) with more or less than 2 inputs: ".Data::Dumper::Dumper(\@inputs));
        die $self->error_message;
    }

    # recurse to find the inputs to this operation
    for my $input (@inputs) {
        push @incoming_links, $self->link_operations($input, $variant_type);
    }
    $unique_combine_name = $self->create_combine_operation( $key , \@incoming_links, $variant_type );

    # return the unique name of the operation created
    return $unique_combine_name;
}

# This sub creates and links in any combine operations.
sub create_combine_operation {
    my $self = shift;
    my $operation_type = shift;
    my $links = shift;
    my $variant_type = shift;
    my $class = 'Genome::Model::Tools::DetectVariants2::Combine::'.ucfirst($operation_type).ucfirst($variant_type);
    eval {
        $class->__meta__;
    };
    if($@){
        $self->error_message("Could not create an instance of ".$class);
        die $self->error_message;
    }

    my $workflow_links = $self->_workflow_links;

    my @links = @{$links};

    # This bit of code (below) allows re-use of detectors. For example, a 
    # strategy which had 'samtools r599 intersect samtools r599 filtered by snp-filter'
    # would run samtools r599 once, then intersect the output of the detector with the 
    # output of the filter, which itself ran on the output of the detector

    ### TODO However! This code only allows shortcutting if one or both of the instances of the 
    ### repeated detector are unfiltered.

    my ($op_a,$op_b);
    my ($alink,$afilter);
    my ($blink,$bfilter);

    if($links[0] =~ m/unfiltered/){
        $afilter = undef;
        $links[0] =~ s/unfiltered//;
    }
    else {
        $afilter = 1;
    }
    $alink = $links[0];
    if($links[1] =~ m/unfiltered/){
        $bfilter = undef;
        $links[1] =~ s/unfiltered//;
    }
    else {
        $bfilter = 1;
    }
    $blink = $links[1];

    my $input_a_key = $alink."_output_directory";
    my $input_b_key = $blink."_output_directory";

    my $input_a_last_op_name = $afilter ? $workflow_links->{$input_a_key}->{'last_operation'} : $alink;
    my $input_b_last_op_name = $bfilter ? $workflow_links->{$input_b_key}->{'last_operation'} : $blink;

    my $workflow_model = $self->_workflow_model;
    my $unique_combine_name = join("-",($operation_type, $alink,$blink));
    $unique_combine_name =  Genome::Utility::Text::sanitize_string_for_filesystem($unique_combine_name);
    my $combine_directory = $self->_temp_staging_directory."/".$variant_type."/".$unique_combine_name;

    my $combine_operation = $workflow_model->add_operation(
        name => join(" ",($operation_type, $alink, $blink)),
        operation_type => Workflow::OperationType::Command->get($class),
    );

    my @properties_to_each_operation =  ( 'reference_build_id', 'aligned_reads_input', 'control_aligned_reads_input');
    for my $property ( @properties_to_each_operation) {
        $workflow_model->add_link(
                left_operation => $workflow_model->get_input_connector,
                left_property => $property,
                right_operation => $combine_operation,
                right_property => $property,
        );
    }

    my $left_operation = $workflow_links->{$input_a_last_op_name."_output_directory"}->{right_operation};
    $workflow_model->add_link(
        left_operation => $left_operation,
        left_property => "output_directory",
        right_operation => $combine_operation,
        right_property => "input_directory_a",
    );
    $left_operation = $workflow_links->{$input_b_last_op_name."_output_directory"}->{right_operation};
    $workflow_model->add_link(
        left_operation => $left_operation,
        left_property => "output_directory",
        right_operation => $combine_operation,
        right_property => "input_directory_b",
    );


    $workflow_links->{$unique_combine_name."_output_directory"}->{value} = $combine_directory;
    $workflow_links->{$unique_combine_name."_output_directory"}->{right_property_name} = 'output_directory';
    $workflow_links->{$unique_combine_name."_output_directory"}->{right_operation} = $combine_operation;
    $workflow_links->{$unique_combine_name."_output_directory"}->{last_operation} = $unique_combine_name;

    # Add this output directory to the list of expected directories so we can compile all LQ variants later
    push @{$self->{_expected_output_directories}->{$variant_type}}, $combine_directory;

    my @new_input_connector_properties = ($unique_combine_name."_output_directory");
    my $input_connector = $workflow_model->get_input_connector;
    my $input_connector_properties = $input_connector->operation_type->output_properties;
    push @{$input_connector_properties}, @new_input_connector_properties;
    $input_connector->operation_type->output_properties($input_connector_properties);

    $workflow_model->add_link(
            left_operation => $workflow_model->get_input_connector,
            left_property => $unique_combine_name."_output_directory",
            right_operation => $combine_operation,
            right_property => "output_directory",
    );

    $self->_workflow_inputs($workflow_links); 

    $self->_workflow_links($workflow_links);
    $self->_workflow_model($workflow_model);
    return $unique_combine_name;
}


sub get_unique_detector_name {
    my $self = shift;
    my $hash = shift;
    my $variant_type = shift;
    my $answer;
    my $params = $hash->{params};
    my $name = $hash->{name};
    my $version = $hash->{version};
    return join("_", ($variant_type, $name, $version, $params) );
}


sub add_detectors_and_filters { 
    my $self = shift;
    my $detector_hash = shift;
    my $workflow_model = shift;
    my $workflow_links;
    my $version; 
    for  $version (keys %$detector_hash) {
        # Get the hashref that contains all the variant types to be run for a given detector version
        my $version_hash = $detector_hash->{$version};

        my ($class,$name);
        for my $variant_type (keys %$version_hash) {
            my @instances_for_variant_type = @{$version_hash->{$variant_type}};
            for my $instance (@instances_for_variant_type) {
                my $params = $instance->{params};
                $class = $instance->{class};
                $name = $instance->{name};
                $version = $instance->{version};
                my $unique_detector_base_name = join( "_", ($variant_type, $name, $version, $params));
                my @filters = @{$instance->{filters}};
                # Make the operation
                my $detector_operation = $workflow_model->add_operation(
                    name => "$variant_type $name $version $params",
                    operation_type => Workflow::OperationType::Command->get($class),
                );
                unless($detector_operation){
                    die $self->error_message("Failed to generate a workflow operation object for ".$class);
                }

                # create filter operations
                for my $filter (@filters){
                    my $foperation = $workflow_model->add_operation(
                        name => join(" ",($unique_detector_base_name,$filter->{name},$filter->{version},$filter->{params})),
                        operation_type => Workflow::OperationType::Command->get($filter->{class})
                    ); 
                    unless($foperation){
                        die $self->error_message("Failed to generate a workflow operation object for ".$filter->{class});
                    }
                    $filter->{operation} = $foperation;
                }

                # add links for properties which every detector has from input_connector
                my @properties_to_each_operation =  ( 'reference_build_id', 'aligned_reads_input', 'control_aligned_reads_input');
                for my $property ( @properties_to_each_operation) {
                    $workflow_model->add_link(
                        left_operation => $workflow_model->get_input_connector,
                        left_property => $property,
                        right_operation => $detector_operation,
                        right_property => $property,
                    );
                }
                
                # compose a hash containing input_connector outputs and the operations to which they connect, then connect them

                # first add links from input_connector to detector
                my $detector_output_directory = $self->calculate_operation_output_directory($self->_temp_staging_directory."/".$variant_type, $name, $version, $params);
                
                my $inputs_to_store;
                $inputs_to_store->{$unique_detector_base_name."_version"}->{value} = $version;
                $inputs_to_store->{$unique_detector_base_name."_version"}->{right_property_name} = 'version';
                $inputs_to_store->{$unique_detector_base_name."_version"}->{right_operation} = $detector_operation;

                $inputs_to_store->{$unique_detector_base_name."_params"}->{value} = $params;
                $inputs_to_store->{$unique_detector_base_name."_params"}->{right_property_name} = 'params';
                $inputs_to_store->{$unique_detector_base_name."_params"}->{right_operation} = $detector_operation;

                $inputs_to_store->{$unique_detector_base_name."_output_directory"}->{value} = $detector_output_directory;
                $inputs_to_store->{$unique_detector_base_name."_output_directory"}->{right_property_name} = 'output_directory';
                $inputs_to_store->{$unique_detector_base_name."_output_directory"}->{right_operation} = $detector_operation;
                $inputs_to_store->{$unique_detector_base_name."_output_directory"}->{last_operation} = $unique_detector_base_name;

                # Add this output directory to the list of expected directories so we can compile all LQ variants later
                push @{$self->{_expected_output_directories}->{$variant_type}}, $detector_output_directory;

                # adding in links from input_connector to filters to the hash
                my $previous_output_directory = $detector_output_directory;
                for my $filter (@filters){
                    my $fname = $filter->{name};
                    my $fversion = $filter->{version};
                    my $fparams = $filter->{params};
                    my $unique_filter_name = join( "_",($unique_detector_base_name,$fname,$fversion,$fparams));
                    my $filter_output_directory = $self->calculate_operation_output_directory($previous_output_directory, $fname, $fversion, $fparams);
                    $previous_output_directory = $filter_output_directory;
                    $inputs_to_store->{$unique_filter_name."_params"}->{value} = $filter->{params};
                    $inputs_to_store->{$unique_filter_name."_params"}->{right_property_name} = 'params';
                    $inputs_to_store->{$unique_filter_name."_params"}->{right_operation} = $filter->{operation};

                    $inputs_to_store->{$unique_filter_name."_output_directory"}->{value} = $filter_output_directory;
                    $inputs_to_store->{$unique_filter_name."_output_directory"}->{right_property_name} = 'output_directory';
                    $inputs_to_store->{$unique_filter_name."_output_directory"}->{right_operation} = $filter->{operation};

                    # Add this output directory to the list of expected directories so we can compile all LQ variants later
                    push @{$self->{_expected_output_directories}->{$variant_type}}, $filter_output_directory;

                    $inputs_to_store->{$unique_detector_base_name."_output_directory"}->{last_operation} = $unique_filter_name;
                }
                
                # use the hash keys, which are input_connector property names, to add the links to the workflow
                for my $property (keys %$inputs_to_store) {
                    $workflow_model->add_link(
                        left_operation => $workflow_model->get_input_connector,
                        left_property => $property,
                        right_operation => $inputs_to_store->{$property}->{right_operation},
                        right_property => $inputs_to_store->{$property}->{right_property_name},
                    );
                }

                # add the properties this variant detector and filters need (version, params,output dir) to the input connector
                my @new_input_connector_properties = (keys %$inputs_to_store);
                my $input_connector = $workflow_model->get_input_connector;
                my $input_connector_properties = $input_connector->operation_type->output_properties;
                push @{$input_connector_properties}, @new_input_connector_properties;
                $input_connector->operation_type->output_properties($input_connector_properties);

                # merge the current detector's inputs to those generated for previous detectors, if any
                my %workflow_inputs;
                if(defined($self->_workflow_inputs)){
                    %workflow_inputs = ( %{$self->_workflow_inputs}, %{$inputs_to_store});
                }
                else {
                    %workflow_inputs = %{$inputs_to_store};
                }
                $self->_workflow_inputs(\%workflow_inputs); 
            
                # connect the output to the input between all operations in this detector's branch
                for my $index (0..(scalar(@filters)-1)){
                    my ($right_op,$left_op);
                    if($index == 0){
                        $left_op = $detector_operation;
                    }
                    else {
                        $left_op = $filters[$index-1]->{operation};
                    }
                    $right_op = $filters[$index]->{operation};
                    $workflow_model->add_link(
                        left_operation => $left_op,
                        left_property => 'result_id',
                        right_operation => $right_op,
                        right_property => 'previous_result_id',
                    );
                    
                }
                $workflow_links = $self->_workflow_links;
                if($workflow_links){
                    my $hash_maker = $workflow_links;
                    %{$workflow_links} = ( %{$hash_maker}, %{$inputs_to_store} );
                }
                else {
                    $workflow_links = $inputs_to_store;
                }
                $self->_workflow_links($workflow_links);
            }
        }
    }
    $self->_workflow_model($workflow_model);
    return $workflow_model;
}

sub _create_directories {
    my $self = shift;
    $self->SUPER::_create_directories(@_);

    # Make a list of the variant types we wish to detect
    my @variant_types;
    for my $type (@{$self->variant_types}){
        my $type_strat = $type."_detection_strategy";
        if(defined($self->$type_strat)){
            push @variant_types, $type;
        }
    }
    # create subdirectories for the variant types we are detecting
    my @subdirs = map {$self->_temp_staging_directory."/".$_ } @variant_types;
    for my $output_directory (@subdirs) {
        unless (-d $output_directory) {
            eval {
                Genome::Sys->create_directory($output_directory);
            };
            
            if($@) {
                $self->error_message($@);
                return;
            }

            $self->status_message("Created directory: $output_directory");
            chmod 02775, $output_directory;
        }
    }

    return 1;
}

sub _create_temp_directories {
    my $self = shift;
    $self->_temp_staging_directory($self->output_directory);
    $self->_temp_scratch_directory($self->output_directory);
    return 1;
}

# After promoting staged data as per normal, create a symlink from the final output files to the top level of the dispatcher output directory
sub _promote_staged_data {
    my $self = shift;
    my $output_dir  = $self->output_directory;

    # This sifts the workflow results for relative paths to output files, and places them in the appropriate params
    $self->set_output_files($self->_workflow_result);

    # Symlink the most recent version bed files of the final hq calls into the base of the output directory
    for my $variant_type (@{$self->variant_types}){
        my $output_accessor = "_".$variant_type."_hq_output_file";
        if(defined($self->$output_accessor)){
            my $file = $self->$output_accessor;
            my @subdirs = split( "/", $file );
            my $output_file = $subdirs[-1];
            my $output = "$output_dir/$output_file";
            Genome::Sys->create_symlink($file,$output);

            # FIXME refactor this when we refactor versioning. This is pretty awful.
            # Create v1 and v2 symlinks to the bed files
            if ($variant_type eq "snv" || $variant_type eq "indel") {
                (my $unversioned_output = $output) =~ s/\.v\d//;
                (my $v2_output = $unversioned_output) =~ s/\.bed/.v2.bed/;
                (my $v1_output = $unversioned_output) =~ s/\.bed/.v1.bed/;

                # Sometimes the .bed file exists already. Sometimes the v2.bed exists already. Make whatever two links do not exist.
                for my  $link_target ($unversioned_output, $v1_output, $v2_output) {
                    unless (-e $link_target) {
                        Genome::Sys->create_symlink($output, $link_target);
                    }
                }

                # Create LQ links also, if an lq file was produced 
                (my $lq_output = $output) =~ s/hq/lq/;
                (my $unversioned_lq_output = $lq_output) =~ s/\.v\d//;
                (my $lq_v2_output = $unversioned_lq_output) =~ s/\.bed/.v2.bed/;
                (my $lq_v1_output = $unversioned_lq_output) =~ s/\.bed/.v1.bed/;
                for my $link_target ($lq_v1_output, $lq_v2_output) {
                    if ( (-e $unversioned_lq_output) && !(-e $link_target) ) {
                        Genome::Sys->create_symlink($unversioned_lq_output, $link_target);
                    }
                }
            }

            $self->$output_accessor($output);
        }
    }

    return 1;
}

# for each strategy input we look in the workflow result for output_directories which we then turn into relative paths, and then into final full paths
sub set_output_files {
    my $self = shift;
    my $result = shift;
    for my $variant_type (@{$self->variant_types}){
        my $file_accessor = "_".$variant_type."_hq_output_file";
        my $strategy = $variant_type."_detection_strategy";
        my $out_dir = $variant_type."_output_directory";
        if(defined( $self->$strategy)){
            my $relative_path = $self->get_relative_path_to_output_directory($result->{$out_dir});
            unless($relative_path){
                $self->error_message("No ".$variant_type." output directory. Workflow returned: ".Data::Dumper::Dumper($result));
                die $self->error_message;
            }
            my $hq_output_dir = $self->output_directory."/".$relative_path; #FIXME complications arise here when we have just a single column file... or other stuff. May just need to drop the version, too?
            my $hq_file;
            if ($variant_type eq 'sv' || $variant_type eq 'cnv'){
                $hq_file = $variant_type."s.hq";
            }else{
                $hq_file = $variant_type."s.hq.bed";
            }
            my $file;
            if(-l $hq_output_dir."/".$hq_file){
                $file = readlink($hq_output_dir."/".$hq_file); # Should look like "dir/snvs_hq.bed" 
                $file = basename($file,['bed']); 
            }
            else{
                $file = $hq_file;
            }
            my $hq_output_file = $hq_output_dir . "/". $file;
            $self->$file_accessor($hq_output_file);
        }
    }
    return 1;
}

# The HQ bed files for each variant type are already symlinked to the base output directory. 
# This method collects all the LQ variants that fell out at each filter and combine stage and sorts them into one LQ output.
# FIXME _validate_output should be added to check that the HQ and LQ bed files totaled have the same line count as each detectors HQ bed output files
sub _generate_standard_files {
    my $self = shift;
    
    # For each variant type that is expected, gather all the lq files that exist for that variant type and sort them into the dispatcher output directory
    for my $variant_type (@{ $self->variant_types }) {
        my $strategy = $variant_type."_detection_strategy";
        if(defined( $self->$strategy)){
            my @lq_files;
            my @output_directories = @{$self->{_expected_output_directories}->{$variant_type}};

            # For each output directory the workflow knows about, look to see if there is an lq file there (there will not be if it was a detector)
            for my $output_directory (@output_directories) {
                my $lq_file = $output_directory . "/$variant_type" . "s.lq.bed";
                if (-e $lq_file) {
                    push @lq_files, $lq_file;
                }
            }

            # If we have no lq files, just skip this variant type. This means we only ran detectors (no filtering, or intersecting) and thus have no LQ files to merge/sort.
            unless (@lq_files) {
                next;
            }

            # Sort the files so they will go into joinx in a predictable order to produce results that will not vary
            my @sorted_lq_files = sort(@lq_files);

            my $output_file = $self->output_directory . "/$variant_type" . "s.lq.bed";
            my $sort_command = Genome::Model::Tools::Joinx::Sort->create(
                input_files => \@sorted_lq_files,
                merge_only => 1,
                output_file => $output_file,
            );

            unless ($sort_command->execute) {
                $self->error_message("Error executing lq sort command");
                die $self->error_message;
            }
        }
    }

    return 1;
}

#if the dispatcher is restarted on the same directory--move the old file (e.g. workflow xml) out of the way
sub _rotate_old_files {
    my $self = shift;
    my $file = shift;

    unless(-e $file) {
        return 1;
    }

    my $i = 1;
    while(-e "$file.$i" && $i <= 20) {
        $i++;
    }

    if($i > 20) {
        die $self->error_message('Too many old files encountered! (Is there a systematic issue, or do old files just need cleaning up?)');
    }

    unless(rename($file, "$file.$i")) {
        die $self->error_message('Failed to move old file out of the way ' . $!);
    }

    return 1;
}


1;
