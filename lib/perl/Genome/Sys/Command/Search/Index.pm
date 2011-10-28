# TODO
# - log4perl
# - add a deamon mode
#   - loop repeatedly over queue (in transaction)
#       - have to reload IndexQueue
#   - signal handler to exit daemon
#   - commit at intervals (how to be safe about this?)
# - lock, single instance?

package Genome::Search::Command::Index;

class Genome::Search::Command::Index {
    is => 'Command::V2',
    has => [
        subject_text => {
            is => 'Text',
            shell_args_position => 1,
        },
        verbose => {
            is => 'Boolean',
            default => 0,
        },
        confirm => {
            is => 'Boolean',
            default => 1,
        },
        debug => {
            is => 'Boolean',
            default => 0,
        },
    ],
};

sub execute {
    my $self = shift;

    my $confirmed = $self->prompt_for_confirmation() if $self->confirm;
    if ($self->confirm && !$confirmed) {
        print "Aborting.\n";
        return;
    }

    if ($self->subject_text eq 'all') {
        $self->index_all;
    }
    elsif ($self->subject_text eq 'queue') {
        $self->index_queue;
    }
    else {
        my $subject = $self->get_subject_from_subject_text();
        $self->index($subject);
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

sub get_subject_from_subject_text {
    my $self = shift;

    my ($subject_class, $subject_id) = $self->subject_text =~ /^(.*)=(.*)$/;
    unless ($subject_class && $subject_id) {
        $self->error_message("Failed to parse subject_text for class and ID. Must be in the form Class=ID.");
        return;
    }

    unless ($subject_class->isa('UR::Object')) {
        $self->error_message("Class ($subject_class) is not recognized as an UR object.");
        return;
    }

    my $subject = $subject_class->get($subject_id);
    unless ($subject) {
        $self->error_message("Failed to get object (Class: $subject_class, ID: $subject_id).");
        return;
    }

    return $subject;
}

sub index_all {
    my $self = shift;

    my @classes_to_index = $self->indexable_classes;
    for my $class (@classes_to_index) {
        $self->status_message("Scanning $class...") if $self->verbose;
        my @subjects = $class->get();
        for my $subject (@subjects) {
            $self->index($subject);
        }
    }

    return 1;
}

sub index_queue {
    my $self = shift;

    my $index_queue_iterator = Genome::Search::IndexQueue->create_iterator(
        '-order_by' => 'timestamp',
    );

    while (my $index_queue_item = $index_queue_iterator->next) {
        my $subject = $index_queue_item->subject;
        if ($self->index($subject)) {
            $index_queue_item->delete();
        }
    }

    return 1;
}

sub index {
    my ($self, $subject) = @_;

    my $class = $subject->class;
    my $id = $subject->id;

    my $rv = eval { Genome::Search->add($subject) };
    if ($rv) {
        $self->status_message("Indexed (Class: $class, ID: $id)") if $self->verbose;
    }
    else {
        $self->error_message("Failed (Class: $class, ID: $id)");
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
            $self->error_message("Class ($class) in searchable_classes is not usable ($use_errors).") if $self->debug;
            next;
        }

        my $class_is_indexable = Genome::Search->is_indexable($class);
        if (!$class_is_indexable) {
            $self->error_message("Class ($class) in searchable_classes is not indexable.") if $self->debug;
            next;
        }

        push @classes_to_add, $class;
    }

    return @classes_to_add;
}
