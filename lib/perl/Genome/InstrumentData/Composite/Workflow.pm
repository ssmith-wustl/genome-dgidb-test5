package Genome::InstrumentData::Composite::Workflow;

use strict;
use warnings;

use Genome;

use Workflow;
use Workflow::Simple qw(run_workflow_lsf);

class Genome::InstrumentData::Composite::Workflow {
    is => 'Command',
    has => [
        inputs => {
            is => 'HASH',
            doc => 'Contains { name => [values] } for the terms in the alignment strategy',
        },
        strategy => {
            is => 'Text',
            doc => 'The alignment strategy to run',
        },
        merge_group => {
            is => 'Text',
            default_value => 'sample',
            valid_values => ['sample', 'all'],
            doc => 'How to group the instrument data when merging',
        },
    ],
    has_transient_optional => [
        _counter => {
            is => 'Number',
            doc => 'for creating unique indices for names',
            default_value => 1,
        },
        _workflow => {
            is => 'Workflow::Model',
            doc => 'The underlying workflow to run the alignment/merge',
            is_output => 1,
        },
        _result_ids => {
            is_many => 1,
            doc => 'The alignments created/found as a result of running the workflow',
            is_output => 1,
        },
        log_directory => {
            is => 'Text',
            doc => 'Where to write the workflow logs',
        }
    ],
};

sub execute {
    my $self = shift;

    $self->status_message('Analyzing strategy...');
    my $strategy = Genome::InstrumentData::Composite::Strategy->create(
        strategy => $self->strategy,
    );
    my $tree = $strategy->execute;

    $self->status_message('Generating workflow...');
    my ($workflow, $inputs) = $self->generate_workflow($tree);
    $self->_workflow($workflow);

    if($self->log_directory) {
        $workflow->log_dir($self->log_directory);
    }
    #print STDERR $workflow->save_to_xml;
    #print STDERR Data::Dumper::Dumper $inputs, "\n";

    my @errors = $workflow->validate;
    if (@errors) {
        $self->error_message(@errors);
        die 'Errors validating workflow';
    }

    $self->status_message('Running workflow...');
    my @results = $self->run_workflow($workflow, $inputs);

    $self->status_message('Produced results: ' . join(', ', @results));
    $self->_result_ids(\@results);

    $self->status_message('Workflow complete.');

    return 1;
}

sub generate_workflow {
    my $self = shift;
    my $tree = shift;

    unless(exists $tree->{data}) {
        die $self->error_message('No data specified in input');
    }

    my $instrument_data_param = $tree->{data};
    my $instrument_data = ($self->inputs)->{$instrument_data_param};
    unless($instrument_data and @$instrument_data) {
        die $self->error_message('No data found for ' . $instrument_data_param);
    }

    my $api_version = $tree->{api_version};
    my $api_inputs = $self->inputs_for_api_version($api_version);

    ### Create per-instrument data alignment workflows

    my %workflows; #hold the per-instrument-data workflows
    my $inputs = []; #hold all the inputs that need to be passed at runtime

    my @alignment_objects = $self->_alignment_objects(@$instrument_data);
    for my $obj (@alignment_objects) {
        my ($workflow, $input) = $self->generate_workflow_for_instrument_data(
            $tree, @$obj,
        );
        $workflows{$obj} = $workflow;
        push @$inputs, @$input;
    }


    ### Create merge operations

    my %merge_operations;
    if(exists $tree->{then}) {
        my ($merge_operations, $input) = %merge_operations = $self->_generate_merge_operations($tree->{then}, \@alignment_objects);
        %merge_operations = %$merge_operations;
        push @$inputs, @$input;
    }


    ### Construct a master workflow to rule them all

    my %input_properties;
    my %output_properties;

    for my $workflow (values %workflows) {
        for my $prop (@{ $workflow->operation_type->input_properties }) {
            $input_properties{$prop}++;
        }
        for my $prop (@{ $workflow->operation_type->output_properties }) {
            $output_properties{$prop}++;
        }
    }

    if(%merge_operations) {
        for my $prop ($self->_merge_workflow_input_properties) {
            $input_properties{$prop}++;
        }

        for my $op (values %merge_operations) {
            for my $prop (@{ $op->operation_type->output_properties }) {
               $output_properties{join('_', $prop, $op->name)}++;
            }
        }
    }

    #just need one copy if same parameter used in multiple subworkflows
    my @input_properties = keys %input_properties;
    my @output_properties = keys %output_properties;

    my $master_workflow = Workflow::Model->create(
        name => 'Master Alignment Dispatcher',
        input_properties => [map('m_' . $_, @input_properties)],
        optional_input_properties => [map('m_' . $_, @input_properties)],
        output_properties => [map('m_' . $_, @output_properties)],
    );


    ### Link all the workflows (and merge operations) together

    for my $workflow (values %workflows) {
        $workflow->workflow_model($master_workflow);

        #wire up the master to the inner workflows (just pass along the inputs and outputs)
        my $master_input_connector = $master_workflow->get_input_connector;
        my $workflow_input_connector = $workflow; #implicitly uses input connector
        for my $property (@{ $workflow->operation_type->input_properties }) {
            $master_workflow->add_link(
                left_operation => $master_input_connector,
                left_property => 'm_' . $property,
                right_operation => $workflow_input_connector,
                right_property => $property,
            );
        }

        my $master_output_connector = $master_workflow->get_output_connector;
        my $workflow_output_connector = $workflow; #implicitly uses output connector
        for my $property (@{ $workflow->operation_type->output_properties }) {
            $master_workflow->add_link(
                left_operation => $workflow_output_connector,
                left_property => $property,
                right_operation => $master_output_connector,
                right_property => 'm_' . $property,
            );
        }
    }

    #add the global inputs
    my %inputs = (%$api_inputs, %{ $self->inputs });
    for my $input ($self->_general_workflow_input_properties) {
        push @$inputs,
            'm_' . $input => $inputs{$input};
    }

    #wire up the merges
    if(%merge_operations) {
        my $master_input_connector = $master_workflow->get_input_connector;
        my $master_output_connector = $master_workflow->get_output_connector;
        for my $merge (values %merge_operations) {
            $merge->workflow_model($master_workflow);

            for my $property ($self->_merge_workflow_input_properties) {
                $master_workflow->add_link(
                    left_operation => $master_input_connector,
                    left_property => 'm_' . $property,
                    right_operation => $merge,
                    right_property => $property,
                );
            }

            for my $property (@{ $merge->operation_type->output_properties }) {
                $master_workflow->add_link(
                    left_operation => $merge,
                    left_property => $property,
                    right_operation => $master_output_connector,
                    right_property => 'm_' . join('_', $property, $merge->name),
                );
            }
        }

        my %converge_inputs_for_group;
        for my $o (@alignment_objects) {
            my $align_wf = $workflows{$o};
            my $group = $self->_merge_group_for_alignment_object($o);

            $converge_inputs_for_group{$group} ||= [];

            push @{ $converge_inputs_for_group{$group} }, @{ $align_wf->operation_type->output_properties };
        }

        my %converge_operation_for_group;
        for my $o (@alignment_objects) {
            my $align_wf = $workflows{$o};
            my $group = $self->_merge_group_for_alignment_object($o);
            my $merge_op = $merge_operations{$group};

            unless(exists $converge_operation_for_group{$group}) {
                my $converge_operation = Workflow::Operation->create(
                    name => join('_', 'converge', $group),
                    operation_type => Workflow::OperationType::Converge->create(
                        input_properties => $converge_inputs_for_group{$group},
                        output_properties => ['alignment_result_ids'],
                    ),
                );

                $converge_operation->workflow_model($master_workflow);
                $master_workflow->add_link(
                    left_operation => $converge_operation,
                    left_property => 'alignment_result_ids',
                    right_operation => $merge_op,
                    right_property => 'alignment_result_ids',
                );

                $converge_operation_for_group{$group} = $converge_operation;
            }

            for my $property (@{ $align_wf->operation_type->output_properties }) {
                $master_workflow->add_link(
                    left_operation => $align_wf,
                    left_property => $property,
                    right_operation => $converge_operation_for_group{$group},
                    right_property => $property,
                );
            }
        }
    }

    return $master_workflow, $inputs;
}

sub inputs_for_api_version {
    my $self = shift;
    my $version = shift;

    my %VERSIONS = (
        'v1' => {
            picard_version => '1.29',
            samtools_version => 'r599',
        },
        'v2' => {
            picard_version => '1.46',
            samtools_version => 'r963',
        },
    );

    unless(exists $VERSIONS{$version}) {
        die($self->error_message('Unknown API version: ' . $version));
    }

    return $VERSIONS{$version};
}


sub _operation_key {
    my $self = shift;
    my $instrument_data = shift;
    my %options = @_;

    my $key = '_operation_' . $instrument_data->id;
    if(exists $options{instrument_data_segment_id}) {
        $key .= '_' . $options{instrument_data_segment_id};
    }

    return $key;
}

sub _create_operations_for_alignment_tree {
    my $self = shift;
    my $tree = shift;
    my $instrument_data = shift;
    my %options = @_;

    my @operations = ();

    return @operations if exists $tree->{$self->_operation_key($instrument_data, %options)}; #generation already complete for this subtree

    push @operations, $self->_generate_operation($tree, $instrument_data);
    if(exists $tree->{parent}) {
        push @operations, $self->_create_operations_for_alignment_tree($tree->{parent}, $instrument_data);
    }

    return @operations;
}

sub generate_workflow_operations{
    my $self = shift;
    my $tree = shift;
    my $instrument_data = shift;
    my %options = @_;

    my @operations = ();
    for my $subtree (@{ $tree->{action} } ) {
        push @operations, $self->_create_operations_for_alignment_tree($subtree, $instrument_data, %options);
    }

    return @operations;
}

sub _instrument_data_params {
    my $self = shift;
    my $instrument_data = shift;

    return (instrument_data_id => $instrument_data->id, instrument_data_filter => ($self->inputs)->{'filter_' . $instrument_data->id});
}

sub _alignment_objects {
    my $self = shift;
    my @instrument_data = @_;

    my @instrument_data_output = map([$_, $self->_instrument_data_params($_)], grep {! $_->can('get_segments')} @instrument_data);
    my @segmentable_data = grep {$_->can('get_segments')} @instrument_data;

    for my $i (@segmentable_data) {
        my @segments = $i->get_segments();
        if (@segments > 1) {
            for my $seg (@segments) {
                push @instrument_data_output, [
                    $i,
                    instrument_data_segment_type => $seg->{segment_type},
                    instrument_data_segment_id => $seg->{segment_id},
                    $self->_instrument_data_params($i),
                ];
            }
        } else {
            push @instrument_data_output, [$i, $self->_instrument_data_params($i)];
        }
    }

    return @instrument_data_output;
}

sub _generate_merge_operations {
    my $self = shift;
    my $merge_tree = shift;
    my $alignment_objects = shift;

    my @inputs = (
        m_merger_name => $merge_tree->{name},
        m_merger_version => $merge_tree->{version},
        m_merger_params => $merge_tree->{params},
    );

    if(exists $merge_tree->{then}) {
        push @inputs, (
            m_duplication_handler_name => $merge_tree->{then}{name},
            m_duplication_handler_params => $merge_tree->{then}{params},
            m_duplication_handler_version => $merge_tree->{then}{version}
        );
    }

    if($self->merge_group eq 'all') {
        #this case is a simplification for efficiency
        return {all => $self->_generate_merge_operation($merge_tree, 'all')}, \@inputs;
    } else {
        #build a list of groups
        my %groups;
        my $grouping = $self->merge_group;

        for my $o (@$alignment_objects) {
            my $group = $self->_merge_group_for_alignment_object($o);
            $groups{$group}++;
        }

        return {map (($_ => $self->_generate_merge_operation($merge_tree, $_)), sort keys %groups)}, \@inputs;
    }
}

sub _merge_group_for_alignment_object {
    my $self = shift;
    my $alignment_object = shift;

    if($self->merge_group eq 'all') {
        return 'all';
    }

    if(ref $alignment_object eq 'ARRAY') {
        #accept either the output of _alignment_objects or a straight instrument_data
        $alignment_object = $alignment_object->[0];
    }

    my $grouping = $self->merge_group;
    my $group_obj = $alignment_object->$grouping;
    unless($group_obj) {
        die $self->error_message('Could not determine ' . $grouping . ' for data ' . $alignment_object->[0]->__display_name__);
    }

   return $group_obj->id;
}

sub _generate_merge_operation {
    my $self = shift;
    my $merge_tree = shift;
    my $grouping = shift;

    my $operation = Workflow::Operation->create(
        name => 'merge_' . $grouping,
        operation_type => Workflow::OperationType::Command->get('Genome::InstrumentData::Command::MergeAlignments'),
    );

    return $operation;
}

sub _instrument_data_workflow_input_properties {
    my $self = shift;
    my $instrument_data = shift;
    my %options = @_;

    my @input_properties = map(
        join('__', $_, $instrument_data->id, (exists $options{instrument_data_segment_id} ? $options{instrument_data_segment_id} : ())),
        ('instrument_data_id', 'instrument_data_segment_id', 'instrument_data_segment_type', 'instrument_data_filter')
    );

    return @input_properties;
}

sub _general_workflow_input_properties {
    my $self = shift;

    return qw(picard_version samtools_version force_fragment);
}

sub _merge_workflow_input_properties {
    my $self = shift;

    return qw(merger_name merger_version merger_params duplication_handler_name duplication_handler_version duplication_handler_params samtools_version);
}

sub generate_workflow_for_instrument_data {
    my $self = shift;
    my $tree = shift;
    my $instrument_data = shift;
    my %options = @_; #segment/read selection

    #First, get all the individual operations and figure out all the inputs/outputs we'll need
    my @operations = $self->generate_workflow_operations($tree, $instrument_data, %options);

    my @input_properties = (
        $self->_general_workflow_input_properties(),
        $self->_instrument_data_workflow_input_properties($instrument_data, %options)
    );
    my @output_properties;

    for my $op (@operations) {
        my $op_name = $op->name;

        if(grep($_ eq 'reference_build_id', @{ $op->operation_type->input_properties })) {
            push @input_properties, join('_','reference_build_id', $op_name);
        }

        push @input_properties, join('_', 'name', $op_name), join('_', 'params', $op_name), join('_', 'version', $op_name);
    }

    for my $leaf (@{ $tree->{action} }) {
        push @output_properties, join('_', 'result_id', $leaf->{$self->_operation_key($instrument_data, %options)}->name);
    }



    #Next create the model, and add all the operations to it
    my $workflow_name = 'Alignment Dispatcher for ' . $instrument_data->id;
    if(exists $options{instrument_data_segment_id}) {
        $workflow_name .= ' (segment ' . $options{instrument_data_segment_id} . ')';
    }

    my $workflow = Workflow::Model->create(
        name => $workflow_name,
        input_properties => \@input_properties,
        optional_input_properties => \@input_properties,
        output_properties => \@output_properties,
    );

    for my $op (@operations) {
        $op->workflow_model($workflow);
    }

    #Last wire up the workflow
    my $inputs_for_links = $self->_generate_alignment_workflow_links($workflow, $tree, $instrument_data, %options);

    return $workflow, $inputs_for_links;
}

sub get_unique_action_name {
    my $self = shift;
    my $action = shift;

    my $index = $self->_counter;
    $self->_counter($index + 1);

    my $name = $action->{name};
    return join('_', $name, $index);
}

sub _generate_operation {
    my $self = shift;
    my $action = shift;
    my $instrument_data = shift;
    my %options = @_;

    my $key = '_operation';
    if($instrument_data) {
        $key = $self->_operation_key($instrument_data, %options);
    }
    return $action->{$key} if exists $action->{$key}; #multiple leaves will point to the same parent, so stop if we've already worked on this subtree

    my $action_class_bases = {
        align => 'Genome::InstrumentData::Command::AlignReads',
        #filter => 'Genome::InstrumentData::Command::Filter', #TODO implement filter support
    };

    my $class_name = $action_class_bases->{$action->{type}};

    eval {
        $class_name->__meta__;
    };
    if($@){
        $self->error_message("Could not create an instance of " . $class_name);
        die $self->error_message;
    }

    my $operation = Workflow::Operation->create(
        name => $self->get_unique_action_name($action),
        operation_type => Workflow::OperationType::Command->get($class_name),
    );

    $action->{$key} = $operation;

    return $operation;
}

sub _generate_alignment_workflow_links {
    my $self = shift;
    my $workflow = shift;
    my $tree = shift;
    my $instrument_data = shift;
    my %options = @_;

    my $inputs = [];
    for my $subtree (@{ $tree->{action} }) {
        my $input = $self->_create_links_for_subtree($workflow, $subtree, $instrument_data, %options);
        push @$inputs, @$input;

        #create link for final result of that subtree
        my $op = $subtree->{$self->_operation_key($instrument_data, %options)};
        $workflow->add_link(
            left_operation => $op,
            left_property => 'result_id',
            right_operation => $workflow->get_output_connector,
            right_property => join('_', 'result_id', $op->name),
        );
    }

    return $inputs;
}

sub _create_links_for_subtree {
    my $self = shift;
    my $workflow = shift;
    my $tree = shift;
    my $instrument_data = shift;
    my %options = @_;

    my $link_key = $self->_operation_key($instrument_data, %options) . '_links';
    return 1 if exists $tree->{$link_key};
    $tree->{$link_key} = 1;

    my $operation = $tree->{$self->_operation_key($instrument_data, %options)};
    die('No operation on tree!') unless $operation;

    my @properties = ('name', 'params', 'version');
    push @properties, 'reference_build_id'
        if ($tree->{type} eq 'align');

    my $inputs = [];
    for my $property (@properties) {
        my $left_property = join('_', $property, $operation->name);
        $workflow->add_link(
            left_operation => $workflow->get_input_connector,
            left_property => $left_property,
            right_operation => $operation,
            right_property => $property,
        );

        my $value;

        if($property eq 'reference_build_id') {
            my $reference = ($self->inputs)->{$tree->{reference}};
            $value = $reference->id;
            unless($value) {
                die $self->error_message('Found no reference for ' . $tree->{reference});
            }
        } else {
            $value = $tree->{$property};
        }

        push @$inputs, (
            'm_'.$left_property => $value,
        );
    }

    for my $property ($self->_general_workflow_input_properties) {
        $workflow->add_link(
            left_operation => $workflow->get_input_connector,
            left_property => $property,
            right_operation => $operation,
            right_property => $property,
        );
    }

    if(exists $tree->{parent}) {
        my $parent_operation = $tree->{parent}{$self->_operation_key($instrument_data, %options)};
        $workflow->add_link(
            left_operation => $parent_operation,
            left_property => 'output_result_id',
            right_operation => $operation,
            right_property => 'alignment_result_input_id',
        );

        return $self->_create_links_for_subtree($workflow, $tree->{parent}, $instrument_data, %options);
    } else {
        #we're at the root--so create links for passing the segment info, etc.
        for my $property ($self->_instrument_data_workflow_input_properties($instrument_data, %options)) {
            my ($simple_property_name) = $property =~ m/^(.+?)__/;
            $workflow->add_link(
                left_operation => $workflow->get_input_connector,
                left_property => $property,
                right_operation => $operation,
                right_property => $simple_property_name,
            );

            push @$inputs, (
                'm_'.$property => $options{$simple_property_name},
            );
        }
    }

    return $inputs;
}

sub run_workflow {
    my $self = shift;
    my $workflow = shift;
    my $inputs = shift;

    my $result = Workflow::Simple::run_workflow_lsf( $workflow, @$inputs);

    unless($result){
        $self->error_message( join("\n", map($_->name . ': ' . $_->error, @Workflow::Simple::ERROR)) );
        die $self->error_message("Workflow did not return correctly.");
    }

    my @result_ids;
    for my $key (keys %$result) {
        if($key =~ /result_id/) {
            push @result_ids, $result->{$key};
        }
    }

    return @result_ids;
}


1;

