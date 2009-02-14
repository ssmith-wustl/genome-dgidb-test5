package Genome::Utility::TestBase;

use strict;
use warnings;

use base 'Test::Class';

use File::Temp 'tempdir';
use Storable qw/ store retrieve /;
use Test::More;

#< CLASS >#
sub create_valid_object { 
    eval "use ".$_[0]->test_class;
    return $_[0]->_create_valid_object;
}

sub _create_valid_object { 
    my $self = shift;
    my $method = $self->new_or_create;
    return $self->test_class->$method( $self->params_for_test_class );
}

sub new_or_create {
    return ( $_[0]->test_class->isa('UR::Object') ) ? 'create' : 'new' ;
}

sub params_for_test_class {
    return;
}

sub required_attrs {
    my %params = $_[0]->params_for_test_class;
    return keys %params;
}

sub invalid_params_for_test_class {
    return;
}

#< DIR >#
sub base_test_dir {
    return '/gsc/var/cache/testsuite/data';
}

sub test_class_sub_dir {
    my @words = $_[0]->test_class =~ /([A-Z](?:[A-Z]*(?=$|[A-Z][a-z])|[a-z]*))/;
    return join('-', @words);
}

sub dir { 
    my $self = shift;

    unless ( $self->{_dir} ) {
        $self->{_dir} = base_dir().'/'.test_class_sub_dir();
    }
    
    return $self->{_dir};
}

sub tmp_dir {
    my $self = shift;

    unless ( $self->{_tmp_dir} ) {
        $self->{_tmp_dir} = tempdir(CLEANUP => 1);
    }
    
    return $self->{_tmp_dir};
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

sub test003_required_attrs : Tests {
    my $self = shift;

    my $method = $self->new_or_create;
    my %params = $self->params_for_test_class
        or return 1;
    for my $attr ( $self->required_attrs ) {
        my $val = delete $params{$attr};
        my $eval;
        eval {
            $eval = $self->test_class->new(%params);
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
            $eval = $self->test_class->new(%params);
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

