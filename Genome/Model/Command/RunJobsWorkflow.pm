package Genome::Model::Command::RunJobsWorkflow;

use strict;
use warnings;
use Genome;
use Workflow;

class Genome::Model::Command::RunJobsWorkflow {
    is => 'Genome::Model::Command::RunJobs',
};

sub help_brief {
    'Launch all jobs for a model using the workflow framework.'
}

sub help_detail {
    return <<EOS 
EOS
}

sub execute {
    my $self = shift;
    my $uniq = 0;

    $DB::single=1;

    my $main_event = Genome::Model::Event->get(
        $self->event_id
    );

    my $chain = Workflow::Model->create(
        name => $main_event->event_type . $uniq++,
        input_properties => [
            'prior_result',
        ],
        output_properties => ['result']
    );
    my $input_connector = $chain->get_input_connector;
    my $output_connector = $chain->get_output_connector;

    my @ops_to_merge = ();
    
    my $z = 0;
    foreach my $child_event ($main_event->child_events(prior_event_id => undef)) {
#        next if defined $child_event->prior_event_id;
        next unless defined $child_event->read_set_id;  ## fix this?  how do i know what stage 1 is.

        my $child_operation = $chain->add_operation(
            name => $child_event->event_type . $uniq++,
            operation_type => Workflow::OperationType::Event->get(
                $child_event->id
            )
        );

        $chain->add_link(
            left_operation => $input_connector,
            left_property => 'prior_result',
            right_operation => $child_operation,
            right_property => 'prior_result'
        );
        
        my $output_connector_linked = 0;
        
        my $sub;
        $sub = sub {
            my $prior_op = shift;
            my $prior_event = shift;
            my @events = $prior_event->next_events;
            
            if (@events) {
                foreach my $c_event (@events) {
                    my $c_operation = $chain->add_operation(
                        name => $c_event->event_type . $uniq++,
                        operation_type => Workflow::OperationType::Event->get(
                            $c_event->id
                        )
                    );
                    
                    $chain->add_link(
                        left_operation => $prior_op,
                        left_property => 'result',
                        right_operation => $c_operation,
                        right_property => 'prior_result'
                    );
                    
                    $sub->($c_operation,$c_event);
                }
            } else {
                
                ## link the op's result to it.
                
                unless ($output_connector_linked) {
                    push @ops_to_merge, $prior_op;
                
                    $output_connector_linked = 1;
                }
            }
        };
        
        $sub->($child_operation,$child_event);

#        print $child_event->event_type . "\n";
        
        $z++;
        last if $z > 5;
    }

    my $i = 1;
    my @input_names = map { 'result_' . $i++ } @ops_to_merge;

    my $converge = $chain->add_operation(
        name => 'merge results',
        operation_type => Workflow::OperationType::Converge->create(
            input_properties => \@input_names,
            output_properties => ['all_results','result']
        )
    );

    $i = 1;
    foreach my $op (@ops_to_merge) {
        $chain->add_link(
            left_operation => $op,
            left_property => 'result',
            right_operation => $converge,
            right_property => 'result_' . $i++
        );
    }

    $chain->add_link(
        left_operation => $converge,
        left_property => 'result',
        right_operation => $output_connector,
        right_property => 'result'
    );

    $chain->as_png("/tmp/test.png");
exit;
#    print $chain->save_to_xml;

#    my $n = $chain->execute(
#        input => {
#            prior_result => 1
#        },
#        output_cb => sub { print "Done\n" },
#        error_cb => sub { print "Error\n" },
#        store => Workflow::Store::None->get()
#    );
    
#    $chain->wait;
    
#    $n->treeview_debug;


    require Workflow::Simple;
    
    $Workflow::Simple::store_db = 0;
    
    Workflow::Simple::run_workflow_lsf(
        $chain,
        prior_result => 1
    );
}

1;
