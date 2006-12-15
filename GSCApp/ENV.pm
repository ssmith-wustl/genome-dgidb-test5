# Change environment as needed for GSC apps
# Copyright (C) 2005 Washington University in St. Louis
#
# This program is free software; you can redistribute it and/or
# modify under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

package GSCApp::ENV;

=pod

=head1 NAME

GSCApp::ENV - Modify environment variables to ensure consistency

=head1 SYNOPSIS

  use GSCApp;
  App->init;

=head1 DESCRIPTION

This module has no methods or exportable variables that sahould be
called.  It provides an initialization method that is called by
App::Init.  This method simply ensures that the environment that the
Perl program is running under is correct.

=cut

use warnings;
use strict;

our $VERSION = '0.1';

use App::Debug;
use App::Init;
use IO::Handle;

our %OENV;

=pod

=head1 METHODS

=over 4

=item fix_env

    App::Init->add_init_subroutine
    (
        'ensure correct environment',
        \&fix_env,
        __PACKAGE__
    );

This method is intended to be called as an initialization method.  You
should not call it directly.

This method ensures that the PATH, LD_LIBRARY_PATH, and Oracle
environment variables are correct.

=cut

sub fix_env
{
    my $class = shift;

    # do not change anything under windows
    return 1 if $^O eq 'MSWin32';

    # save original environment in accessible variable
    our %OENV = %ENV;

    # set executable path ($PATH)
    my @bin = split(m/:/, $ENV{PATH});
    my @path;
    # make sure appsrv comes before everything but $HOME/bin
    if ($bin[0] eq "$ENV{HOME}/bin")
    {
        push(@path, shift(@bin));
    }
    if ($bin[0] ne '/gsc/scripts/bin')
    {
        # insert appsrv paths
        push(@path, qw(/gsc/scripts/bin /gsc/bin /gsc/java/bin /gsc/teTeX/bin));
    }
    # add rest of directories to path
    push(@path, @bin);

    # set library path ($LD_LIBRARY_PATH)
    $ENV{LD_LIBRARY_PATH} = "" if not defined $ENV{LD_LIBRARY_PATH};
    my @lib = split(m/:/, $ENV{LD_LIBRARY_PATH});
    my @ld_library_path;
    # make sure /gsc/lib is first
    if (!@lib or $lib[0] ne '/gsc/lib')
    {
        push(@ld_library_path, '/gsc/lib');
    }
    # add rest of directories
    push(@ld_library_path, @lib);

    # oracle enviroment variables
    my $oracle_version = ($^V ge v5.8.0) ? '9.2' : '8.1';
    $ENV{ORACLE_BASE} ||= '/gsc/pkg/oracle';
    $ENV{ORACLE_HOME} = "$ENV{ORACLE_BASE}/$oracle_version";
    $ENV{ORACLE_BIN} = "$ENV{ORACLE_HOME}/bin";
    $ENV{TNS_ADMIN} = "$ENV{ORACLE_HOME}/network/admin";
    $ENV{OBK_HOME} = "$ENV{ORACLE_HOME}/obackup";
    $ENV{ORA_NLS32} = "$ENV{ORACLE_HOME}/ocommon/nls/admin/data";
    $ENV{ORACLE_DOC} = "$ENV{ORACLE_HOME}/doc";
    my @oracle_path = split(m/:/, $ENV{ORACLE_PATH});
    # search PATH, LD_LIBRARY_PATH, and ORACLE_PATH for oracle directories
    foreach my $dir (@path, @ld_library_path, @oracle_path)
    {
        $dir =~ s{^$ENV{ORACLE_BASE}/[^/]+}{$ENV{ORACLE_HOME}};
    }

    # put environment variables back together
    $ENV{PATH} = join(':', @path);
    $ENV{LD_LIBRARY_PATH} = join(':', @ld_library_path);
    $ENV{ORACLE_PATH} = join(':', @oracle_path);

    if (App::Debug->level > 3)
    {
        foreach my $env (keys(%ENV))
        {
            STDERR->print("$env=$ENV{$env} ($OENV{$env})\n") if $ENV{$env} ne $OENV{$env};
        }
    }

    return 1;
}

# Call the above immediately.
# It must return true for the module to return true.
fix_env();

__END__

=pod

=back

=head1 BUGS

Report bugs to <software@watson.wustl.edu>.

=head1 SEE ALSO

GSCApp(3), App::Init(3)

=head1 AUTHOR

David Dooling <ddooling@watson.wustl.edu>

=cut

# $Header$
