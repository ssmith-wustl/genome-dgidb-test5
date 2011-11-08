package Genome::Sys::Command::Search::Index;

use Genome;

class Genome::Sys::Command::Search::Index {
    is => ['Genome::Role::Logger', 'Command'],
    has => [
        action => {
            is => 'Text',
            default => 'add',
            valid_values => ['add', 'delete'],
        },
        subject_text => {
            is => 'Text',
            shell_args_position => 1,
        },
        confirm => {
            is => 'Boolean',
            default => 1,
        },
        max_changes_per_commit => {
            is => 'Number',
            default => 250,
        },
    ],
};

sub execute {
    my $self = shift;

    if ($self->subject_text ne 'list') {
        my $confirmed = $self->prompt_for_confirmation() if $self->confirm;
        if ($self->confirm && !$confirmed) {
            $self->info('Aborting.');
            return;
        }
    }

    if ($self->subject_text eq 'all') {
        $self->index_all;
    }
    elsif ($self->subject_text eq 'queued') {
        $self->index_queued;
    }
    elsif ($self->subject_text eq 'daemon') {
        $self->daemon;
    }
    elsif ($self->subject_text eq 'list') {
        $self->list;
    }
    else {
        die "Not able to modify specific items at this time";
    }

    return 1;
}

sub prompt_for_confirmation {
    my $self = shift;

    my $solr_server = $ENV{GENOME_SYS_SERVICES_SOLR};
    print "Are you sure you want to rebuild the index for the search server at $solr_server? ";
    my $response = <STDIN>;
    chomp $response;
    $response = lc($response);

    return ($response =~ /^(y|yes)$/);
}

sub index_all {
    my $self = shift;

    my $action = $self->action;

    my @classes_to_index = $self->indexable_classes;
    for my $class (@classes_to_index) {
        $self->info("Scanning $class...");
        my @subjects = $class->get();
        for my $subject (@subjects) {
            $self->modify_index($subject, $action);
        }
    }

    return 1;
}

my $signaled_to_quit;
sub daemon {
    my $self = shift;

    local $SIG{INT} = sub { $signaled_to_quit = 1 };
    local $SIG{TERM} = sub { $signaled_to_quit = 1 };

    while (!$signaled_to_quit) {
        $self->info("Processing index queue...");
        $self->index_queued(max_changes_count => $self->max_changes_per_commit);

        $self->info("Commiting...");
        UR::Context->commit;

        $self->info("Sleeping for 10 seconds...");
        sleep 10;

        $self->info("Reloading Genome::Search::IndexQueue...");
        UR::Context->reload('Genome::Search::IndexQueue');
    }

    return 1;
}

sub list {
    my $self = shift;

    my $index_queue_iterator = Genome::Search::IndexQueue->create_iterator(
        '-order_by' => 'timestamp',
    );

    while (my $index_queue_item = $index_queue_iterator->next) {
        print join("\t",
            $index_queue_item->timestamp,
            $index_queue_item->action,
            $index_queue_item->subject_class,
            $index_queue_item->subject_id,
        ) . "\n";
    }

    return 1;
}

sub index_queued {
    my $self = shift;
    my %params = @_;

    my $max_changes_count = delete $params{max_changes_count};

    my $index_queue_iterator = Genome::Search::IndexQueue->create_iterator(
        '-order_by' => 'timestamp',
    );

    my $modified_count = 0;
    while (
        !$signaled_to_quit
        && (!defined($max_changes_count) || $modified_count <= $max_changes_count)
        && (my $index_queue_item = $index_queue_iterator->next)
    ) {
        my $action = $index_queue_item->action;
        my $subject = $index_queue_item->subject;
        if ($self->modify_index($subject, $action)) {
            $index_queue_item->delete();
            $modified_count++;
        }
    }

    return 1;
}

sub modify_index {
    my ($self, $subject, $action) = @_;

    my $class = $subject->class;
    my $id = $subject->id;
    my $display_name = "(Class: $class, ID: $id)";

    my $rv = eval { Genome::Search->$action($subject) };
    my $error = $@;
    if ($rv) {
        my $display_action = ($action eq 'add' ? 'Added' : 'Deleted');
        $self->info("$display_action $display_name");
    }
    else {
        my $display_action = ($action eq 'add' ? 'Failed to add' : 'Failed to delete');
        $self->info("$display_action $display_name\n$@");
    }

    return $rv;
}

sub indexable_classes {
    my $self = shift;

    my @searchable_classes = Genome::Search->searchable_classes();

    my @classes_to_add;
    for my $class (@searchable_classes) {
        eval "use $class";
        my $use_errors = $@;
        if ($use_errors) {
            $self->debug("Class ($class) in searchable_classes is not usable ($use_errors).");
            next;
        }

        my $class_is_indexable = Genome::Search->is_indexable($class);
        if (!$class_is_indexable) {
            $self->debug("Class ($class) in searchable_classes is not indexable.");
            next;
        }

        push @classes_to_add, $class;
    }

    return @classes_to_add;
}

1;
