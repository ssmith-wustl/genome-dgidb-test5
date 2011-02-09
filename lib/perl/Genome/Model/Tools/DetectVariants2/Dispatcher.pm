package Genome::Model::Tools::DetectVariants2::Dispatcher;

use strict;
use warnings;

use Clone qw/clone/;
use Data::Dumper;
use JSON;
use Genome;
use Workflow;
use Workflow::Simple;

class Genome::Model::Tools::DetectVariants2::Dispatcher {
    is => ['Genome::Model::Tools::DetectVariants2::Base'],
    doc => 'This tool is used to handle delegating variant detection to one or more specified tools and filtering and/or combining the results',
    has_optional => [
        _workflow_inputs => {
            doc => "Inputs to pass into the workflow when executing",
        },
        snv_hq_output_file => {
            is => 'String',
            is_output => 1,
            doc => 'High Quality SNV output file',
        },
        indel_hq_output_file => {
            is => 'String',
            is_output => 1,
            doc => 'High Quality indel output file',
        },
        sv_hq_output_file => {
            is => 'String',
            is_output => 1,
            doc => 'High Quality SV output file',
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

    ],
    has_constant => [
        variant_types => {
            is => 'ARRAY',
            value => [('snv', 'indel', 'sv')],
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
    $DB::single=1;
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
    $input->{reference_sequence_input} = $self->reference_sequence_input;
    $input->{output_directory} = $self->_temp_staging_directory;#$self->output_directory;
   
    $self->_dump_workflow($workflow);

    $self->status_message("Now launching the dispatcher workflow.");
    my $result = Workflow::Simple::run_workflow_lsf( $workflow, %{$input});

    unless($result){
        die $self->error_message("Workflow did not return correctly.");
    }
    
    if(defined( $self->snv_detection_strategy)){
        my $snv_output_directory = $result->{snv_output_directory};
        unless($snv_output_directory){
            $self->error_message("No SNV output directory was returned from the workflow. Workflow DID return: ".Data::Dumper::Dumper($result));
            die $self->error_message;
        }
        my $snv_hq_output_file = "$snv_output_directory/snvs.hq.v1.bed"; #FIXME complications arise here when we have just a single column file... or other stuff. May just need to drop the version, too?
        $self->snv_hq_output_file($snv_hq_output_file);
    }
    if(defined( $self->sv_detection_strategy)){
        my $sv_output_directory = $result->{sv_output_directory};
        unless($sv_output_directory){
            $self->error_message("No SV hq output file was returned from the workflow. Workflow DID return: ".Data::Dumper::Dumper($result));
            die $self->error_message;
        }
        my $sv_hq_output_file = "$sv_output_directory/svs.hq.v1.bed"; #FIXME complications arise here when we have just a single column file... or other stuff. May just need to drop the version, too?
        $self->sv_hq_output_file($sv_hq_output_file);
    }
    if(defined( $self->indel_detection_strategy)){
        my $indel_output_directory = $result->{indel_output_directory};
        unless($indel_output_directory){
            $self->error_message("No indel hq output file was returned from the workflow. Workflow DID return: ".Data::Dumper::Dumper($result));
            die $self->error_message;
        }
        my $indel_hq_output_file = "$indel_output_directory/indels.hq.v1.bed"; #FIXME complications arise here when we have just a single column file... or other stuff. May just need to drop the version, too?
        $self->indel_hq_output_file($indel_hq_output_file);
    }

    return 1;
}

sub _dump_workflow {
    my $self = shift;
    my $workflow = shift;
    my $xml = $workflow->save_to_xml;
    my $xml_location = $self->output_directory."/workflow.xml";
    my $xml_file = Genome::Sys->open_file_for_writing($xml_location);
    print $xml_file $xml;
    $xml_file->close;
    #$workflow->as_png($self->output_directory."/workflow.png");
}

sub calculate_operation_output_directory {
    my $self = shift;
    $DB::single =1;
    my ($base_directory, $variant_type, $name, $version, $param_list) = @_;
    my $subdirectory = join('-', $variant_type, $name, $version, $param_list);
    
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
    my @output_properties;

    push @output_properties, 'snv_output_directory' if defined ($self->snv_detection_strategy);
    push @output_properties, 'sv_output_directory' if defined ($self->sv_detection_strategy);
    push @output_properties, 'indel_output_directory' if defined ($self->indel_detection_strategy);

    my $workflow_model = Workflow::Model->create(
        name => 'Somatic Variation Pipeline',
        input_properties => [
            'reference_sequence_input',
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
        $workflow_model = $self->generate_workflow_operation($detector_hash, $workflow_model);
    }

    # TODO union and intersect each post-filtering detector output if necessary

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
                my @filters = @{$instance->{filters}};
                print Data::Dumper::Dumper(\@filters);

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
                        name => $filter->{name}." ".$filter->{version}." ".$filter->{params},
                        operation_type => Workflow::OperationType::Command->get($filter->{class})
                    ); 
                    unless($foperation){
                        die $self->error_message("Failed to generate a workflow operation object for ".$filter->{class});
                    }
                    $filter->{operation} = $foperation;
                }

                # add links for properties which every operation has from input_connector to each operation
                for my $op ($detector_operation, map{$_->{operation} } @filters){
                    for my $property ( 'reference_sequence_input', 'aligned_reads_input', 'control_aligned_reads_input') {
                         $workflow_model->add_link(
                            left_operation => $workflow_model->get_input_connector,
                            left_property => $property,
                            right_operation => $op,
                            right_property => $property,
                        );
                    }
                }
                
                # compose a hash containing input_connector outputs and the operations to which they connect, then connect them

                # first add links from input_connector to detector
                my $unique_detector_base_name = join("_", ($variant_type, $name, $version, $params) );
                my $detector_output_directory = $self->calculate_operation_output_directory($self->_temp_staging_directory, $variant_type, $name, $version, $params);
                
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
                
                # adding in links from input_connector to filters to the hash
                for my $index (0..(scalar(@filters)-1)){
                    my $filter = $filters[$index];
                    my $fname = $filter->{name};
                    my $fversion = $filter->{version};
                    my $fparams = $filter->{params};
                    my $unique_filter_name = join( "_",($unique_detector_base_name,$fname,$fversion,$fparams));
                    my $filter_output_directory = $self->calculate_operation_output_directory($detector_output_directory, $variant_type, $fname, $fversion, $fparams);

                    $inputs_to_store->{$unique_filter_name."_params"}->{value} = $filter->{params};
                    $inputs_to_store->{$unique_filter_name."_params"}->{right_property_name} = 'params';
                    $inputs_to_store->{$unique_filter_name."_params"}->{right_operation} = $filter->{operation};

                    $inputs_to_store->{$unique_filter_name."_output_directory"}->{value} = $filter_output_directory;
                    $inputs_to_store->{$unique_filter_name."_output_directory"}->{right_property_name} = 'output_directory';
                    $inputs_to_store->{$unique_filter_name."_output_directory"}->{right_operation} = $filter->{operation};
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

                print Data::Dumper::Dumper($self->_workflow_inputs);
            
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
                        left_property => 'output_directory',
                        right_operation => $right_op,
                        right_property => 'input_directory',
                    );
                    
                }

                # Find which is the last operation and connect it to the output connector
                my $last_operation;
                if(scalar(@filters)>0){
                    $last_operation = $filters[-1]->{operation};
                }
                else {
                    $last_operation = $detector_operation;
                }

                $workflow_model->add_link(
                    left_operation => $last_operation,
                    left_property => "output_directory",
                    right_operation => $workflow_model->get_output_connector,
                    right_property => $variant_type."_output_directory",
                );
            }
        }
    }

    return $workflow_model;
}

sub _create_temp_directories {
    my $self = shift;

    $ENV{TMPDIR} = $self->output_directory;

    return $self->SUPER::_create_temp_directories(@_);
}

sub _promote_staged_data {
    my $self = shift;
    my $staging_dir = $self->_temp_staging_directory;
    my $output_dir  = $self->output_directory;
    if(defined($self->snv_hq_output_file)){
        my $file = $self->snv_hq_output_file;
        my $output = $staging_dir."/snvs.hq.v1.bed";
        Genome::Sys->create_symlink($file,$output);
        $self->snv_hq_output_file($output);
    }
    if(defined($self->sv_hq_output_file)){
        my $file = $self->sv_hq_output_file;
        my $output = $staging_dir."/svs.hq.v1.bed";
        Genome::Sys->create_symlink($file,$output);
        $self->sv_hq_output_file($output);
    }
    if(defined($self->indel_hq_output_file)){
        my $file = $self->indel_hq_output_file;
        my $output = $staging_dir."/indels.hq.v1.bed";
        Genome::Sys->create_symlink($file,$output);
        $self->indel_hq_output_file($output);
    }
    unless($self->SUPER::_promote_staged_data(@_)){
        $self->error_message("_promote_staged_data failed in Dispatcher");
        die $self->error_message;
    }
    return 1;
}

1;
