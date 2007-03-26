package Runtests;

use strict;
use warnings FATAL => 'all';

use Moose;
#with 'MooseX::Getopt';
use English;
use File::chdir '$CWD';
use Path::Class ();
use File::Slurp ();

our $VERSION = '0.01';

has 'db_variant' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    default  => sub {
        eval q{ use GSCApp; App->init; };
        return App::DB->db_variant;
    },
);

has 'output_file' => (
    is       => 'ro',
    isa      => 'Path::Class::File',
    required => 1,
    lazy     => 1,
    default  => sub { Path::Class::dir($CWD)->file('runtests.out') },
);

has 'cmd_exit_code' => (
    is  => 'rw',
    isa => 'Num',
);

has 'cover' => (
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
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

has 'all_tests_successful' => (
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
    lazy     => 1,
    default  => sub {
        my $self = shift;
        die 'cannot access all_tests_successful until cmd has been run'
            if ( !$self->cmd_has_been_run );
        if ( $self->cmd_exit_code != 0 ) {
            return 0;
        }
        my $output = $self->output || '';
        if ( $output =~ m{^All [ ] tests [ ] successful}xms ) {
            return 1;
        }
        return 0;
    },
);

has 'failure_summary' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    lazy     => 1,
    default  => sub {
        my $self = shift;
        die 'cannot access failure_summary until cmd has been run'
            if ( !$self->cmd_has_been_run );
        my $output = $self->output || '';
        return ''
            if ( $output
            !~ m{(^Failed [ ] Test.*List [ ] of [ ] Failed.*)}xms );
        my $summary = $1;
        my $cmd     = $self->cmd;
        my %env     = $self->env;
        my $env     = join( "\n", map {"$_=$env{$_}"} sort keys %env );
        return "$env\n$cmd\n\n$summary";
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
        return [] if ( $self->all_tests_successful );
        my $summary = $self->failure_summary;
        my @failed_tests;
        for ( split( /\n/, $summary ) ) {
            last if (m{^\d+ test skipped}xms);
            last if (m{^Failed [ ] .* subtests [ ] failed}xms);
            next if (m{^([\w\/]+\.t)}xms);
            push @failed_tests, $1;
        }
        die 'could not parse out failed tests' if ( @failed_tests == 0 );
        return \@failed_tests;
    },
);

has 'cmd' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    lazy     => 1,
    default  => sub {
        my $self = shift;
        my $cmd  = "env && $EXECUTABLE_NAME ./Makefile.PL ";
        $cmd .= ' && make';
#        $cmd .= ' && make test';
#        my $cmd  = 'env';
        $cmd .= " && $EXECUTABLE_NAME util/lsf_harness.pl";
#        $cmd .= " && $EXECUTABLE_NAME util/lsf_harness.pl App/t/*.t GSCApp/t/*.t";
        return $cmd;
    },
);

sub runtests {
    my $self = shift;
    my $cmd = $self->cmd;
    my $output_file = $self->output_file;
    $cmd = "($cmd) > $output_file 2>&1";
    local %ENV = ( %ENV, $self->env );
    my $output = `$cmd`;
    $self->cmd_exit_code($?);
}

sub cmd_has_been_run {
    my $self = shift;
    return defined $self->cmd_exit_code;
}

sub output {
    my $self = shift;
    die 'cannot access output until cmd has been run'
        if ( !$self->cmd_has_been_run );
    my $output_file = $self->output_file;
    my $output = File::Slurp::slurp("$output_file");
    return $output;
}

1;
__END__


=head1 NAME

Runtests - encapsulate how we run tests

=head1 VERSION

Version 0.01

=cut

=head1 SYNOPSIS

Run the tests, collect the output, and report basic results.

    use Runtests;

    my $r = Runtests->new(...);
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

