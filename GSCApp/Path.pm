# Customize App::Path for GSC
# Copyright (C) 2004 Washington University in St. Louis
#
# This program is free software; you can redistribute it and/or
# modify under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

# set package name for module
package GSCApp::Path;

=pod

=head1 NAME

GSCApp::Path - customize path management for GSC

=head1 SYNOPSIS

To submit a mail message from an application:

    use GSCApp;

=head1 DESCRIPTION

These methods customize the path management for the GSC application
server.

=cut

# set up package
require 5.6.0;
use warnings;
use strict;
our $VERSION = '0.2';
use App::Path;

# set the path to installed scripts
if ($^O eq 'MSWin32')
{
    App::Path->prefix('//winsvr.gsc.wustl.edu/gsc/scripts');
}
else
{
    App::Path->prefix('/gsc/scripts');
}

# switch over to App::Path to implement mail and smail
package App::Path;
use warnings;
use strict;
use base qw(App::MsgLogger);

=pod

=head2 METHODS

These methods customize the App::Path methods for the GSC application
server.

=over 4

=item get_path

=cut

# save original get_path
my $orig_get_path;
BEGIN { $orig_get_path = *App::Path::get_path{CODE}; }

# do not complain that these subroutines are redefined
no warnings 'redefine';

sub get_path
{
    my $class = shift;
    my ($path_name, $pkg) = @_;

    # var is a special case
    my $old_prefix;
    if ($path_name eq 'var')
    {
        # alter prefix
        $old_prefix = $class->prefix;
        my $new_prefix = $old_prefix;
        if ($^O eq 'MSWin32')
        {
            # remove /gsc/scripts
            $new_prefix =~ s,/gsc/scripts,,;
        }
        else
        {
            # remove /scripts
            $new_prefix =~ s,/scripts,,;
        }
        $class->prefix($new_prefix);
    }

    # get the paths
    my @paths = $orig_get_path->($class, @_);

    if ($old_prefix)
    {
        # set prefix back
        $class->prefix($old_prefix);
    }

    return @paths;
}

1;
__END__

=pod

=back

=head1 BUGS

Report bugs to <software@watson.wustl.edu>.

=head1 SEE ALSO

App(3), App::Path(3), GSCApp(3)

=head1 AUTHOR

David Dooling <ddooling@watson.wustl.edu>

=cut

# $Header$
