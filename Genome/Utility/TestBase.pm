package Genome::Utility::TestBase;

use strict;
use warnings;

use base 'Test::Class';

use Data::Dumper 'Dumper';
use File::Temp 'tempdir';
use Storable qw/ store retrieve /;
use Test::More;

#< CLASS >#
sub create_object { # public method for creating
    my $self = shift;
    eval "use ".$self->test_class;
    return $self->_create_object(@_);
}

sub create_valid_object { # public method for creating
    my $self = shift;
    eval "use ".$self->test_class;
    return $self->_create_valid_object(@_);
}

sub _create_valid_object { 
    return $_[0]->_create_object( $_[0]->params_for_test_class );
}

sub _create_object {
    my $self = shift;
    my $method = $self->new_or_create;
    return $self->test_class->$method(@_);
}

sub new_or_create {
    return ( $_[0]->test_class->isa('UR::Object') ) ? 'create' : 'new' ;
}

sub params_for_test_class {
    return;
}

sub required_attrs {
    return;
}

sub required_params_for_class {
    my $self = shift;

    unless ( $self->test_class->isa('UR::Object') ) {
        return $self->required_attrs;
    }
    
    my @params;
    for my $property ( $self->test_class->get_class_object->property_metas ) {
        next if defined $property->default_value;
        next if $property->is_optional;
        next if $property->id_by;
        next if $property->via;
        next if $property->calculate;
        next if $property->property_name =~ /^_/;
        push @params, $property->property_name;
    }
        
    return @params;
}

sub invalid_params_for_test_class {
    return;
}

sub alternate_params_for_test_class {
    return;
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

#< Mocking >#
sub create_mock {
    my $self = shift;

    # TODO - move all mocking from UR::Object to here or into UR::Object::Mock
    return $self->test_class->create_mock(id => -10000, $self->params_for_test_class );
}

sub mock_accessors {
    my ($self, $obj, @methods) = @_;

    no strict 'refs';
    for my $method ( @methods ) {
        $obj->mock(
            $method,
            sub{
                my ($obj, $param) = @_;
                $obj->{$method} = $param if defined $param;
                return $obj->{$param}; 
            },
        );
    }

    return 1;
}

sub mock_methods {
    my ($self, $obj, $class, @methods) = @_;

    no strict 'refs';
    for my $method ( @methods ) {
        my $class_method = $class.'::'.$method;
        $obj->mock(
            $method,
            sub{ &{$class_method}(@_); },
        );
    }

    return 1;
}

#< Helper Methods >#
sub store_file  {
    my ($self, $ref, $file) = @_;
    
    die "Invalid ref to store\n" unless $ref and ref $ref;
    
    Genome::Utility::FileSystem->validate_file_for_writing($file)
        or die;
    
    return store($ref, $file);
}

sub retrieve_file {
    my ($self, $file) = @_;

    Genome::Utility::FileSystem->validate_file_for_reading($file)
        or die;
    
    return retrieve($file);
}

#< Base Tests >#
sub test001_use : Test(1) {
    my $self = shift;

    use_ok( $self->test_class )
        or die;

    return 1;
}

sub test002_create : Test(2) {
    my $self = shift;

    $self->{_object} = $self->_create_valid_object;
    ok($self->{_object}, "Created ".$self->test_class);
    isa_ok($self->{_object}, $self->test_class);

    return 1;
}

sub test003_required_params : Tests {
    my $self = shift;

    my %params = $self->params_for_test_class
        or return 1;
    my $method = $self->new_or_create;
    for my $attr ( $self->required_params_for_class ) {
        my $val = delete $params{$attr};
        my $eval;
        eval {
            $eval = $self->_create_object(%params);
        };
        ok(!$eval, "Failed as expected - create w/o $attr");
        $params{$attr} = $val;
    }

    return 1;
}

sub test004_invalid_params : Tests {
    my $self = shift;

    my %invalid_params = $self->invalid_params_for_test_class
        or return 1;
    
    my $method = $self->new_or_create;
    my %params = $self->params_for_test_class;
    for my $attr ( keys %invalid_params ) {
        my $val = delete $params{$attr};
        $params{$attr} = $invalid_params{$attr};
        my $eval;
        eval {
            $eval = $self->_create_object(%params);
        };

        diag("$@\n");
        ok(!$eval, "Failed as expected - create w/ invalid $attr");
        $params{$attr} = $val;
    }

    return 1;
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

