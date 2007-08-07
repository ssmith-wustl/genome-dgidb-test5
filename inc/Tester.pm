package Tester;

use strict;
use warnings FATAL => 'all';

our $VERSION = '0.01';

use Moose;
with 'MooseX::Getopt';
use English;
use File::chdir '$CWD';
use IO::Handle;
use IO::File;
use Path::Class ();
use YAML::Syck;
use Test::TAP::Model::Smoke;
use Test::TAP::Model::LSF;

has 'db_variant' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    lazy     => 1,
    default  => sub {
        my $self = shift;
        my $db_variant;
        $self->_fork_run(
            sub {
                @ARGV = ();
                eval q{ use GSCApp; App->init; };
                print App::DB->db_variant, "\n";
            },
            sub { $db_variant = shift },
        );
        chomp $db_variant;
        return $db_variant;
    },
);

has 'cover' => (
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
    lazy     => 1,
    default  => sub {0},
);

has 'merge_env' => (
    is         => 'ro',
    isa        => 'HashRef',
    required   => 1,
    auto_deref => 1,
    default    => sub { {} },
);

has 'env' => (
    is         => 'ro',
    isa        => 'HashRef',
    required   => 1,
    auto_deref => 1,
    lazy       => 1,
    default    => sub {
        my $self = shift;
        my %env  = (
            APP_DB_VARIANT    => $self->db_variant,
            APP_DBI_NO_COMMIT => 1,
            GSCAPP_TEST_QUIET => 0,
            TEST_VERBOSE      => 1,
        );
        $env{HARNESS_PERL_SWITCHES} = '-MDevel::Cover' if $self->cover;
        %env = ( %env, $self->merge_env );
        return \%env;
    },
);

has 'tests' => (
    is         => 'rw',
    isa        => 'ArrayRef',
    required   => 1,
    lazy       => 1,
    auto_deref => 1,
    default    => sub {
        my $self = shift;
        my @tests = map { glob("$_") } $self->test_globs;
        return \@tests;
    },
);

has 'test_globs' => (
    is         => 'ro',
    isa        => 'ArrayRef',
    required   => 1,
    lazy       => 1,
    auto_deref => 1,
    default    => sub {
        # run all tests by default
        [qw(App/t/*.t GSC/t/*.t GSCApp/t/*.t)];
    },
);

has 'all_tests_successful' => (
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
    lazy     => 1,
    default  => sub {
        my $self = shift;
        my @fail = $self->failed_tests;
        return @fail ? 0 : 1;
    },
);

has 'failure_summary' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    lazy     => 1,
    default  => sub {
        my $self = shift;
        return '' if $self->all_tests_successful;
        my %env    = $self->env;
        my $env    = join( "\n", map {"$_=$env{$_}"} sort keys %env );
        my @failed = $self->failed_tests;
        return "$env\n\nFailed tests:\n" . join( "\n", @failed, '' );
    },
);

has 'failed_tests' => (
    is         => 'ro',
    isa        => 'ArrayRef',
    required   => 1,
    auto_deref => 1,
    lazy       => 1,
    default    => sub {
        my $self = shift;
        die 'cannot access failed_tests until we have a model'
            if ( !$self->model );
        my %status = $self->model->status;
        my @not_pass = grep { $status{$_} ne 'PASS' } keys %status;
        return \@not_pass;
    },
);

has 'callback' => (
    is       => 'rw',
    isa      => 'CodeRef',
    required => 1,
    default  => sub { sub { } },
);

# work around new_with_options()
sub model { shift->_model(@_) }
has '_model' => (
    is  => 'rw',
    isa => 'Test::TAP::Model',
);

sub status {
    my $self = shift;
    return $self->model->status;
}

sub run_tests {
    my $self = shift;
    my @tests = $self->tests;
    die "no tests specified" if ( @tests == 0 );

    # prepare to run the tests
    local %ENV = ( %ENV, $self->env );
    $self->_fork_run( sub { system('env') } );
    $self->_fork_run( sub { system("$EXECUTABLE_NAME ./Makefile.PL") } );
    $self->_fork_run( sub { system('make') } );

    my $class;
    if ($self->cover) {
        # run serially
        $class = 'Test::TAP::Model::Smoke';
    }
    else {
        # run in parallel via LSF
        $class = 'Test::TAP::Model::LSF';
    }
    my $model = $class->new or die;
    $model->handler($self->callback);
    $model->run_tests(@tests);
    $self->model($model);

    $self->callback->("writing tests.yml...");
    DumpFile('tests.yml', $model->structure);
    $self->callback->("finished\n");

    # fool Test::Harness into thinking the tests were run locally
    $ENV{HARNESS_STRAP_CLASS} ||= 'Test::TAP::Model::LSF';
    $self->_fork_run( sub {
        require Test::Harness;
        Test::Harness::runtests(@tests);
    });

    return $self->model->status;
}

sub _fork_run {
    my $self = shift;
    my $code = shift;
    my $callback = shift || $self->callback;
    my $fh = IO::File->new or die;
    my $pid = $fh->open('-|');
    defined $pid or die "fork failed: $!";
    if ($pid) {
        # parent
        while ( my $line = $fh->getline ) {
            $callback->($line);
        }
        wait;
    }
    else {
        # child
        open( STDERR, ">&", STDOUT );   # tie them together
        STDOUT->autoflush(1);
        STDERR->autoflush(1);
        $code->();
        exit;
    }
}

1;
__END__


=head1 NAME

Tester - encapsulate how we run tests

=head1 VERSION

Version 0.01

=cut

=head1 SYNOPSIS

Run the tests, collect the output, and report basic results.

    use Tester;

    my $r = Tester->new(...);
    $r->runtests;
    if ( !$r->all_tests_successful ) {
        print $r->failure_summary;
    }

=head1 METHODS

=head2 new

Takes the following optional arguments:

=over 4

=over 4

=item I

And arrayref of paths to be used on the commandline with -I.  Defaults
to using no -I flags.

=item db_variant

String passed to the --db flag.  Defaults to App::DB->db_variant.

=back

=back

=cut

=head2 cmd

The full runtests command that is used.

=cut

=head2 runtests

Actually execute the runtests command and collect the output.

=cut

=head2 output_file

Returns the C<Path::Class::File> object for the file that the C<cmd>
output was redirected to.

=cut

=head2 output

After running the tests is completed, this method will return the output,
both STDOUT and STDERR, as an arrayref.

=cut

=head2 all_tests_successful

Returns a true value if all tests were successful.  False otherwise.

=cut

=head2 failure_summary

Returns the failure summary from the output if all the tests were not
successful.

=cut

=head1 AUTHOR

Todd Hepler, C<< <thepler at watson.wustl.edu> >>

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2007 Todd Hepler, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

