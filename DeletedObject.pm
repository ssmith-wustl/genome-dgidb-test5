
package DeletedObject;

our $all_objects_deleted = {};

=pod

    When an object is deleted it is reblessed into this class,
    its underlying hash is emptied, and its class is recorded.

    Attempts to use the hashref as the object it used-to be
    are caught by AUTOLOAD below, and result in a clear error message.

    The deleted object can be resurrected

=cut

our %burried;

sub bury
{
    my $class = shift;

    foreach my $object (@_)
    {
        $burried{ref($object)}{$object->{id}} = 1;
        %$object = (original_class => ref($object), original_data => {%$object});
        bless $object, 'DeletedObject';
        $all_objects_deleted->{"$object"} = 1;
    }

    return 1;
}

sub resurrect
{
    shift unless (ref($_[0]));

    foreach my $object (@_)
    {
        delete $all_objects_deleted->{"$object"};
        bless $object, $object->{original_class};
        %$object = (%{$object->{original_data}});
        $object->resurrect_object if ($object->can('resurrect_object'));
    }

    return 1;
}

sub undestroyed_deleted_objects
{
    my @values = keys(%$all_objects_deleted);
    return @values;
}

sub is_deleted { return 1; }

use Data::Dumper;

sub AUTOLOAD
{
    Carp::confess("Attempt to use a reference to an object which has been deleted with method $AUTOLOAD\nRessurrect it first.\n" . Dumper($_[0]));
}

sub DESTROY
{
    # print "Destroying @_\n";
    delete $all_objects_deleted->{"$_[0]"};
}

1;
#$Header$
