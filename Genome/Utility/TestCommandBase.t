#! /gsc/bin/perl

use strict;

use above 'Genome';

use Data::Dumper 'Dumper';
use Test::More;

# Command to test
class Genome::Utility::TestCommandBase::Tester {
    has => [
    name => { is => 'Text', },
    ],
    has_optional => [
    is_hairy => { is => 'Boolean', default_value => 0, },
    ],
};
*Genome::Utility::TestCommandBase::Tester::create = sub{ 
    my $self = UR::Object::create(@_)
        or return;

    unless ( $self->name ) {
        $self->error_message('No name given');
        return;
    }
    
    if ( $self->name eq '' ) { # tests invalid param set #1
        $self->error_message('Name can\'t be an empty string');
        return;
    }

    return $self; 
};
*Genome::Utility::TestCommandBase::Tester::execute = sub{
    my $self = shift;

    # birds aren't hairy - testing execute failure w/ invalid param set (#2)
    if ( $self->name =~ /bird/i and $self->is_hairy ) {
        $self->error_message($self->name." can't be hairy.  He's a bird");
        return;
    }

    return 1; 
};
use warnings;

#####################################################

package Genome::Utility::TestCommandBase::Tester::Test;

use base 'Genome::Utility::TestCommandBase';

use Test::More;

sub test_class {
    return 'Genome::Utility::TestCommandBase::Tester';
}

sub valid_param_sets {
    return (
        {
            name => 'Fredbird',
            before_execute => '_before_execute',
            after_execute => sub{ 
                my ($self, $obj, $param_set) = @_;
                note('after execute via anon sub');
                isa_ok($self, 'Genome::Utility::TestCommandBase::Tester::Test');
                ok($obj, 'Got object in before execute');
                ok($param_set, 'Got param set in before execute');
                return 1;
            },
        },
        {
            name => 'Louie',
            is_hairy => 1,
            before_execute => sub{ 
                my ($self, $obj, $param_set) = @_;
                note('before execute via anon sub');
                isa_ok($self, 'Genome::Utility::TestCommandBase::Tester::Test');
                ok($obj, 'Got object in before execute');
                ok($param_set, 'Got param set in before execute');
                return 1;
            },
            after_execute => '_after_execute',
        },
    );
}

sub invalid_param_sets {
    return (
        { # blank name
            name => '',
        },
        { # the name for this parm set should be from valid param set 1
            is_hairy => 1,
            # the before/after executes will work cuz this params set will 
            #  create ok, thyen fail in execute
            before_execute => '_before_execute',
            after_execute => '_after_execute',
        },
    );
}

sub _before_execute { 
    my ($self, $obj, $param_set) = @_;
    note('before execute via method');
    isa_ok($self, 'Genome::Utility::TestCommandBase::Tester::Test');
    ok($obj, 'Got object in before execute');
    ok($param_set, 'Got param set in before execute');
    return 1;
}

sub _after_execute { 
    my ($self, $obj, $param_set) = @_;
    note('after execute via method');
    isa_ok($self, 'Genome::Utility::TestCommandBase::Tester::Test');
    ok($obj, 'Got object in _post_execute');
    ok($param_set, 'Got param set in before execute');
    return 1;
}

sub test01_dirs : Test(4) {
    my $self = shift;
    
    is($self->base_test_dir, '/gsc/var/cache/testsuite/data', 'Base test directory');
    is($self->test_class_sub_dir, 'Genome-Utility-TestCommandBase-Tester', 'Test class sub directory');
    is(
        $self->dir, 
        '/gsc/var/cache/testsuite/data/Genome-Utility-TestCommandBase-Tester',
        'Directory',
    );
    can_ok($self, 'tmp_dir');
    
    return 1;
}

#####################################################

package main;

Genome::Utility::TestCommandBase::Tester::Test->runtests;

exit;

1;

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2006 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

