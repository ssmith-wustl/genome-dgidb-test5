package Genome::Utility::TestCommandBase;

use strict;
use warnings;

use base 'Test::Class';

use Carp 'confess';
use Data::Dumper 'Dumper';
use File::Temp 'tempdir';
use Test::More;

#< CLASS >#
sub test_class { return; }
sub _pre_execute { return 1; }
sub _post_execute { return 1; }

#< Params and Properties >#
sub valid_param_sets { 
    return ( {} ); # Default will be to run w/o any params.
}

sub invalid_params {
}

sub invalid_param_sets {
    return;
}

sub required_property_names {
    my $self = shift;

    unless ( $self->test_class->can('get_class_object') ) {
        return $self->required_attrs;
    }
    
    my @names;
    for my $property ( $self->test_class->__meta__->property_metas ) {
        next if defined $property->default_value;
        next if $property->is_optional;
        next if $property->id_by;
        next if $property->reverse_as;
        next if $property->via;
        next if $property->calculate;
        next if $property->property_name =~ /^_/;
        push @names, $property->property_name;
    }
        
    return @names;
}

#< DIR >#
sub base_test_dir {
    return '/gsc/var/cache/testsuite/data';
}

sub test_class_sub_dir {
    return join('-', split('::', $_[0]->test_class));
}

sub dir { 
    return $_[0]->base_test_dir.'/'.$_[0]->test_class_sub_dir;
}

sub tmp_dir {
    my $self = shift;

    unless ( $self->{_tmp_dir} ) {
        $self->{_tmp_dir} = tempdir(CLEANUP => 1);
    }
    
    return $self->{_tmp_dir};
}

#< Base Tests >#
sub test001_test_class : Tests() {
    my $self = shift;

    # test class
    my $test_class = $self->test_class;
    ok($test_class, 'Test class defined.');

    # class meta/use
    unless ( $test_class->can('__meta__') ) {
        use_ok($test_class) or confess;
    }
    ok($test_class->__meta__, 'Got class meta.') or confess;

    # execute
    can_ok($test_class, 'execute') or confess;

    return 1;
}

sub test002_valid_param_sets : Tests() {
    # Goes thru the valid param sets, creating and execute the command
    my $self = shift;

    my @param_sets = $self->valid_param_sets
        or return 1;
    my $cnt = 0;
    for my $param_set ( @param_sets ) {
        $cnt++;
        note( sprintf("%s VALID param set %s", $self->test_class, $cnt) );
        is(ref($param_set), "HASH", "Valid param set ($cnt) isa HASH ref") or confess;
        my $obj;
        eval { $obj = $self->test_class->create(%$param_set); };
        diag("$@\n") if $@;
        ok($obj, 'Created') or confess;
        isa_ok($obj, $self->test_class) or confess;
        $self->_pre_execute($obj) or confess "Failed pre execute";
        my $execute_rv;
        eval { $execute_rv = $obj->execute; };
        diag("$@\n") if $@;
        ok($execute_rv, "Execute") or confess;
        $self->_post_execute($obj) or confess "Failed post execute";
    }

    return 1;
}

sub test003_required_params : Tests {
    my $self = shift;

    # Check if we have vlaues in valid param set #1
    my $params = ($self->valid_param_sets)[0];
    return ok(1, 'No need to test required properties - no values in valid param set') unless %$params;
    
    my @required_property_names = $self->required_property_names;
    return ok(1, 'No need to test required properties - they are none') unless @required_property_names;
    
    for my $property_name ( @required_property_names ) {
        note($self->test_class." required property => $property_name");
        # remove value
        my $val = delete $params->{$property_name};
        # create and execute - contiue thru rest of req properties even if one fails
        $self->_create_and_execute_expected_to_fail(%$params);
        # reset the value
        $params->{$property_name} = $val;
    }

    return 1;
}


sub test004_invalid_param_sets : Tests() {
    # These param sets are invalid for one reason or another and should fail create or execute.
    #  The first valid param set will be used.  The keys in the inval;id set will 
    #  replace the valid set.  The command will then be created and executed, expecting failure.
    my $self = shift;

    my @param_sets = $self->invalid_param_sets
        or return 1;
    my $valid_params = ($self->valid_param_sets)[0];
    my $cnt = 0;
    for my $params ( @param_sets ) {
        $cnt++;
        note( sprintf("%s INVALID param set %s", $self->test_class, $cnt) );
        is(ref($params), "HASH", "Invalid param set ($cnt) isa HASH ref") or confess;
        # copy the valid params
        my %invalid_params = %$valid_params;
        # replace w/ the invalid params
        for my $param ( keys %$params ) {
            $invalid_params{$param} = $params->{$param};
        }
        # create and execute - contiue thru rest of invalid params even if one fails
        $self->_create_and_execute_expected_to_fail(%invalid_params);
    }

    return 1;
}

# helpers
sub _create_and_execute_expected_to_fail {
    my ($self, %params) = @_;

    # create
    my $obj;
    eval { $obj = $self->test_class->create(%params); };
    if ( not $obj or $@ ) { # good - check object or eval error
        diag("$@\n") if $@;
        ok(1, "Failed as expected on create");
        return 1;
    }

    # execute
    my $rv;
    eval { $rv = $obj->execute; };
    
    if ( not $rv or $@ ) { # good - check return value or eval error
        diag("$@\n") if $@;
        ok(1, "Failed as expected on execute");
        return 1;
    }

    # bad - did not fail creat of execute
    ok(0, "DID NOT fail as expected during create or execute");

    return;
}

1;

=pod

=head1 Name

ModuleTemplate

=head1 Synopsis

=head1 Usage

=head1 Methods

=head2 

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head1 See Also

=head1 Disclaimer

Copyright (C) 2005 - 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

