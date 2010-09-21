#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Test::MockObject;
use Test::More;

use_ok('Genome::Model::Build::Command') or die;

class Genome::Model::Build::Command::Tester {
    is => 'Genome::Model::Build::Command',
};

# mock'd
my $old_build = Test::MockObject->new();
$old_build->set_always('id', 1);
$old_build->set_always('status', 'Succeeded');
my $build = Test::MockObject->new();
$build->set_always('id', 2);
$build->mock('status', sub{ 
        my ($self, $status) = @_;
        if ( $status ) { $self->{status} = $status };
        return $self->{status};
    });
$build->status('Failed');
my $model = Test::MockObject->new();
$model->set_always('id', 11);
$model->set_always('name', 'Barack Obama');
$model->set_list('builds', $old_build, $build);
my $model_group = Test::MockObject->new();
$model_group->set_always('id', 111);
$model_group->set_always('name', 'Democrats for Obama');
$model_group->set_list('models', $model);

# overload
no warnings qw/ once redefine /;
*Genome::Model::Build::get = sub{
    my ($class, %params) = @_;

    if ( $params{id} ) {
        return grep { $_->id eq $params{id} } $old_build, $build;
    }

    return;
};
*Genome::Model::get = sub{
    my ($class, %params) = @_;

    if ( $params{id} ) {
        return $model if $model->id == $params{id}
    }
    elsif ( $params{name} ){
        return $model if $model->name eq $params{name}
    }
    elsif ( my $name_like = $params{'name like'} ){
        $name_like =~ s/\%/\.\*/g;
        my $regexp = qr/$name_like/;
        return $model if $model->name =~ $regexp;
    }

    return;
};
*Genome::ModelGroup::get = sub{
    my ($class, %params) = @_;

    if ( $params{id} ) {
        return $model_group if $model_group->id == $params{id}
    }
    elsif ( $params{name} ){
        return $model_group if $model_group->name eq $params{name}
    }

    return;
};
use warnings;

# test getting from cmdline
my $tester = Genome::Model::Build::Command::Tester->create();
ok($tester, 'created tester');
my @builds;
eval{ @builds = $tester->_builds_for_filter(); };
ok((!@builds && $@ =~ /Get builds from command line called without filter/), 'failed to get builds w/o filter');

$tester->filter(1);
@builds = eval{ $tester->_builds_for_filter(); };
is_deeply(\@builds, [ $old_build ], 'old build by id');

$tester->filter(2);
@builds = eval{ $tester->_builds_for_filter(); };
is_deeply(\@builds, [ $build ], 'build by id');

$tester->filter('1,2');
@builds = eval{ $tester->_builds_for_filter(); };
is_deeply(\@builds, [ $old_build, $build ], 'both builds by ids');

$tester->filter(11);
@builds = eval{ $tester->_builds_for_filter(); };
is_deeply(\@builds, [ $build ], 'build by model id');

$tester->filter(111);
@builds = eval{ $tester->_builds_for_filter(); };
is_deeply(\@builds, [ $build ], 'build by model group id');

$tester->filter('Bush');
@builds = eval{ $tester->_builds_for_filter(); };
is_deeply(\@builds, [], 'no builds for Bush');

$tester->filter('%Obama%');
@builds = eval{ $tester->_builds_for_filter(); };
is_deeply(\@builds, [ $build ], 'build by model name like');

$tester->filter('Democrats for Obama');
@builds = eval{ $tester->_builds_for_filter(); };
is_deeply(\@builds, [ $build ], 'build by model group name');

done_testing();
exit;

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2010 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

