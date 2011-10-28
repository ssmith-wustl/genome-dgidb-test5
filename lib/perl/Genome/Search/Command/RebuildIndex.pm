package Genome::Search::Command::RebuildIndex;

class Genome::Search::Command::RebuildIndex {
    is => 'Command::V2',
    has => [
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

our $command_rv = 1;;

sub execute {
    my $self = shift;

    my $confirmed = $self->prompt_for_confirmation() if $self->confirm;
    if ($self->confirm && !$confirmed) {
        print "Aborting.\n";
        return;
    }

    my @classes_to_add = $self->addable_classes;
    for my $class (@classes_to_add) {
        if ($self->verbose) {
            $self->status_message("Scanning $class...");
        }
        my @objects = $class->get();
        for my $object (@objects) {
            $self->add_object_to_search_index($object);
        }
    }

    return $command_rv;
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

sub add_object_to_search_index {
    my ($self, $object) = @_;

    my $class = $object->class;
    my $id = $object->id;

    my $rv = eval { Genome::Search->add($object) };
    if ($rv) {
        if ($self->verbose) {
            $self->status_message("Added object (Class: $class, ID: $id).");
        }
    }
    else {
        $self->error_message("Failed to add object (Class: $class, ID: $id).");
        $command_rv = 0;
    }

    return $rv;
}

sub addable_classes {
    my $self = shift;

    my @searchable_classes = Genome::Search->searchable_classes();

    my @classes_to_add;
    for my $class (@searchable_classes) {
        eval "use $class";
        my $use_errors = $@;
        if ($use_errors) {
            if ($self->debug) {
                $self->error_message("Class ($class) in searchable_classes is not usable ($use_errors).");
            }
            $command_rv = 0;
            next;
        }

        my $class_is_indexable = Genome::Search->is_indexable($class);
        if (!$class_is_indexable) {
            if ($self->debug) {
                $self->error_message("Class ($class) in searchable_classes is not indexable.");
            }
            $command_rv = 0;
            next;
        }

        push @classes_to_add, $class;
    }

    return @classes_to_add;
}
