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
    ],
};

sub execute {
    my $self = shift;

    my $confirmed = $self->prompt_for_confirmation() if $self->confirm;
    if ($self->confirm && !$confirmed) {
        $self->info('Aborting.');
        return;
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
    elsif ($self->subject_test eq 'list') {
        $self->list;
    }
    else {
        my $action = $self->action();
        my $subject_iterator = $self->get_subject_iterator_from_subject_text();
        while (my $subject = $subject_iterator->next) {
            $self->modify_index($subject, $action);
        }
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

sub get_subject_iterator_from_subject_text {
    my $self = shift;

    my ($subject_class, $subject_bx_string);
    if ($self->subject_text =~ /=/) {
        ($subject_class, $subject_bx_string) = $self->subject_text =~ /(.*?)=(.*)/;
    }
    else {
        $subject_class = $self->subject_text;
    }

    unless ($subject_class) {
        $self->error("Failed to parse subject_text (" . $self->subject_text . ") for class. Must be in the form Class or Class=ID.");
        return;
    }

    unless ($subject_class->isa('UR::Object')) {
        $self->error("Class ($subject_class) is not recognized as an UR object.");
        return;
    }

    my $subject_bx = UR::BoolExpr->resolve_for_string($subject_class, $subject_bx_string);
    if ($subject_bx_string && !$subject_bx) {
        $self->error("Invalid BoolExpr provided (Class: $subject_class, BX: $subject_bx_string).");
        return;
    }

    my $subject_iterator = $subject_class->create_iterator($subject_bx);
    unless ($subject_iterator) {
        $subject_bx_string ||= '';
        $self->error("Failed to get iterator (Class: $subject_class, BX: $subject_bx_string).");
        return;
    }

    return $subject_iterator;
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

sub daemon {
    my $self = shift;

    my $loop = 1;
    local $SIG{INT} = sub { $loop = 0 };
    while ($loop) {
        $self->index_queued;
        UR::Context->commit;
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

    my $index_queue_iterator = Genome::Search::IndexQueue->create_iterator(
        '-order_by' => 'timestamp',
    );

    while (my $index_queue_item = $index_queue_iterator->next) {
        my $action = $index_queue_item->action;
        my $subject = $index_queue_item->subject;
        if ($self->modify_index($subject, $action)) {
            $index_queue_item->delete();
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
