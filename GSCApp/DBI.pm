# Run a query or two on the GSC databases.
# Copyright (C) 2005 Washington University in St. Louis
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

=cut

# fool gsc-scripts
package GSCApp::DBI;

=cut

package App::DBI;
our $PACKAGE = '1.0';

=pod

=head1 NAME

GSCApp::DBI - Augment App::DBI with GSC-specific methods.

=head1 SYNOPSIS

  use GSCApp;

  $id = App::DB->dbh->employee_id;
  
GSCApp::DBI extends App::DBI, which is inherited from DBI, so all the 
methods available to a DBI or App::DBI object, e.g., commit and rollback, 
are available to a App::DBI object. See L<DBI(3)> for the details of DBI.pm.
See L<App::DBI(3)> for the details of the generic App/DBI.pm

=cut

require 5.6.0;
use warnings;
use strict;
use Carp;
use base qw(DBI);

## methods

=pod

=head1 METHODS

=over 4

=cut

### database handle sub-class
package App::DBI::db;
use base qw(DBI::db);

# dtor: call the disconnect method
no warnings qw(redefine);
# purposely redefined?
sub DESTROY
{
    my $self = shift;
    # reconsecrate as DBI::db to call its DESTROY
    bless($self, qw(DBI::db));
    return;
}
use warnings;

## public methods

=pod

=item employee_id

  App::DB->dbh->employee_id;
  App::DB->dbh->employee_id($uid);

Returns the database ei_id of the user id specified, or the current
user of the application if no user is specified.  Returns false on
error.

=cut

# determine and return the employee id of the person running this module
our $employee_id;
sub employee_id
{
    my $self = shift;
    my ($uid) = @_;

    # check if we should determine employee id for current user
    unless (defined($uid))
    {
        # if we already know it, return it
        return $employee_id if $employee_id;
        # set to current user
        $uid = $>;
    }
    if ($uid !~ m/^\d+$/)
    {
        $self->set_err(1, "uid is not numeric: $uid");
        return;
    }

    return if ($^O eq 'MSWin32' || $^O eq 'cygwin');

    # get login id
    my $login = getpwuid($uid);
    if (!$login)
    {
        $self->set_err(1, "failed to get login for uid $uid");
        return;
    }

    # look up employee id
    my $q = <<"EOQ";
SELECT ei.ei_id
  FROM employee_infos ei
    JOIN gsc_users gu on gu.gu_id = ei.gu_gu_id
  WHERE gu.unix_login = ?
    AND ei.us_user_status = 'active'
EOQ
    my ($id) = $self->selectrow_array($q, {}, $login);
    if (!defined($id))
    {
        $self->set_err(1, "failed to obtain employee id: $q: " . $self->errstr);
        return;
    }

    # set the package variable if getting the id for the current user
    $employee_id = $id if $uid == $>;

    return $id;
}

### statement handle sub-class
package App::DBI::st;
use base qw(DBI::st);

1;
__END__

=pod

=back

=head1 BUGS

Report bugs to <software@watson.wustl.edu>.

=head1 AUTHORS

David Dooling <ddooling@watson.wustl.edu>

=cut

# $Header$
