# TouchAppProd configuration.
# Copyright (C) 2006 Washington University in St. Louis
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

package TouchScreen::Config;

=pod

=head1 NAME

TouchScreen::Config - manage TouchAppProd configuration

=head1 SYNOPSIS

  $rv = TouchScreen::Config->config_file();
  $val = TouchScreen::Config->config('key');
  %conf = TouchScreen::Config->config;

=head1 DESCRIPTION

This module manages the configuration for TouchAppProd.  Configuration
files are read from a file with named touchN.conf usually in
/gsc/scripts/share/touchscreen/conf, where touchN is the name of the
touchscreen the application is running on.

=cut

# set up package
require 5.6.0;
use warnings;
use strict;
our $VERSION = '0.2';
use base qw(App::Config);
use App::Name;
use App::Path;
use Sys::Hostname;

=pod

=over 4

=item config_file

  $rv = TouchScreen::Config->config_file();

This method reads in the touch screen configuration file, if there is
one.  The file should be in the search path (see L<App::Path>) and
have the same basename as the host running the application and have a
C<.conf> extension.

The method returns true if the file is read in successfuly, zero (0)
is the no configuration file exists, and C<undef> on failure.

=cut

sub config_file
{
    my $self = shift;

    my (%opts) = @_;

    my $host = hostname;
    if ($host)
    {
        $self->debug_message("using hostname: $host", 4);
    }
    else
    {
        $self->error_message("unable to determine host name");
        return;
    }
    $host =~ s/\..*//;
    $self->debug_message("using unqualified host: $host", 4);
    my ($path) = App::Path->find_files_in_path("$host.conf", 'share',
                                               App::Name->pkg_name() . "/conf");
    if ($path && -f $path && -r $path)
    {
        return $self->SUPER::config_file(path => $path);
    }
    # else
    return 0;
}

=pod

=item config

  $val = TouchScreen::Config->config('key');
  %conf = TouchScreen::Config->config;

This method returns one or all of the configuration values.

=item check_config

  $val = TouchScreen::Config->check_config('key');

This method returns one of the configuration values, but does not
complain if the key does not exist.

=back

=head1 BUGS

Please report bugs to <software@watson.wustl.edu>.

=head1 SEE ALSO

App(3), App::Config(3)

=head1 AUTHOR

David Dooling <ddooling@watson.wustl.edu>

=cut

# $Header$
