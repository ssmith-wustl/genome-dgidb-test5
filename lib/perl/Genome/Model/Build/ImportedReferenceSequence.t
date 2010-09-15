#! /gsc/bin/perl
#
# 2010 aug 31 ebelter
# Tests did not exist! I made tests to cover the code I wrote. Tests are not comprehensive!
#

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Genome::Utility::TestBase;
use Test::More;

use_ok('Genome::Model::Build::ImportedReferenceSequence') or die;

# Create a model w/ builds 
my $mock_model = Genome::Utility::TestBase->create_mock_object(
    class => 'Genome::Model::ImportedReferenceSequence',
    name => 'IRS Test',
);
Genome::Utility::TestBase->mock_methods($mock_model, '__display_name__');
my @mock_builds;
for (1..2) {
    my $mock_build = Genome::Utility::TestBase->create_mock_object(
        class => 'Genome::Model::Build::ImportedReferenceSequence',
        model => $mock_model,
        version => $_,
    );
    push @mock_builds, $mock_build; 
}
$mock_model->mock('builds', sub{ return @mock_builds});

# Overload get in model and build to return the mocked ones
no warnings;
*Genome::Model::ImportedReferenceSequence::get = sub {
    my $class = shift;
    if ( @_ == 1 ) { # id, should only be one for test
        my $ids = $_[0];
        return $mock_model if $mock_model->id eq $ids->[0];
    }
    else { # name
        my %params = @_;
        if ( ref $params{name} ) {
            return $mock_model if grep { $mock_model->name eq $_ } @{$params{name}};
        }
        else {
            return $mock_model if $mock_model->name eq $params{name};
        }
    }
    return;
};

*Genome::Model::Build::ImportedReferenceSequence::get = sub {
    my $class = shift;
    if ( not @_ ) { # all
        return @mock_builds;
    }
    elsif ( @_ == 1 ) { # id, should only be one for test
        my $ids = $_[0];
        my @builds = grep { $_->id eq $ids->[0] } @mock_builds;
        return @builds if @builds;
    }
    else { # name
        my %params = @_;
        my @builds = grep { $_->name eq $params{name} } @mock_builds;
        return @builds if @builds;
    }
    return;
};
use warnings;

# From command line
my @found_builds;
eval{
    Genome::Model::Build::ImportedReferenceSequence->from_cmdline();
};
ok(
    (@found_builds == 0 && $@ =~ /^Imported reference sequence builds get from command line called in void context/),
    'from_cmdline fails in void context'
);
eval{
    @found_builds = Genome::Model::Build::ImportedReferenceSequence->from_cmdline();
};
ok(
    (@found_builds == 0 && $@ =~ /^Nothing specified to get imported reference sequence builds from command line/),
    'from_cmdline fails w/o params'
);
@found_builds = Genome::Model::Build::ImportedReferenceSequence->from_cmdline($mock_model->id);
is_deeply(\@found_builds, [$mock_builds[1]], 'Got latest build by model id');
@found_builds = Genome::Model::Build::ImportedReferenceSequence->from_cmdline($mock_builds[0]->id);
is_deeply(\@found_builds, [$mock_builds[0]], 'Got build by id');
@found_builds = Genome::Model::Build::ImportedReferenceSequence->from_cmdline($mock_model->name);
is_deeply(\@found_builds, [$mock_builds[1]], 'Got latest build for model name w/ spaces');
@found_builds = Genome::Model::Build::ImportedReferenceSequence->from_cmdline($mock_builds[0]->name);
is_deeply(\@found_builds, [$mock_builds[0]], 'Got build for version 1');
@found_builds = Genome::Model::Build::ImportedReferenceSequence->from_cmdline($mock_builds[1]->name);
is_deeply(\@found_builds, [$mock_builds[1]], 'Got build for version 2');
@found_builds = ();
eval{
    @found_builds = Genome::Model::Build::ImportedReferenceSequence->from_cmdline('unknown');
};
ok(
    (@found_builds == 0 && $@ =~ /^Cannot find imported reference sequence builds for: "unknown"/),
    'no build for "unknown" build name'
);

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

