#
# This class implements the SQLite caching mechanism
# for LSFSpool, allowing it to track progress of workload.
#

package Genome::Model::Tools::LSFSpool::Cache;

use strict;
use warnings;
use Data::Dumper;

use English;

use Cwd 'abs_path';
use DBI;
use Time::HiRes qw(usleep);
use File::Basename;
use File::Find::Rule;

use Exception::Class::TryCatch;
use Genome::Model::Tools::LSFSpool::Error;

# -- Subroutines
#
sub create {
  my $class = shift;
  my $self = {
    parent => shift,
  };
  bless $self, $class;
  return $self;
}

sub error {
  # Raise an Exception object.
  my $self = shift;
  Genome::Model::Tools::LSFSpool::Error->throw( error => @_ );
}

sub logger {
  my $self = shift;
  my $fh = $self->{parent}->{logfh};
  print $fh localtime() . ": @_";
}

sub local_debug {
  my $self = shift;
  $self->logger("DEBUG: @_")
    if ($self->{parent}->{debug});
}

sub sql_exec {
  # Execute SQL.  Retry N times then give up.
  my $self = shift;
  my $sql = shift;

  my @args = @_;
  my $dbh = $self->{dbh};
  my $sth;

  my $attempts = 0;

  $self->error("no database handle, run prep()\n")
    if (! defined $dbh);

  while (1) {

    my $result;
    my $max_attempts = 3;

    try eval {
      $sth = $dbh->prepare($sql);
    };
    if (catch my $err) {
      $self->error("could not prepare sql: " . $err->{message});
    }

    $self->local_debug("sql_exec($sql)\n");
    my @row;
    try eval {
      $sth->execute(@args);
      @row = $sth->fetchrow_array();
    };
    # Note: we expect only one row
    if ( catch my $err ) {
      $attempts += 1;
      if ($attempts >= $max_attempts) {
        $self->error("failed during execute $attempts times, giving up: $err->{message}\n");
      } else {
        $self->logger("failed during execute $attempts times, retrying: $err->{message}\n");
      }
      usleep(10000);
    } else {
      return @row;
    }
  }
}

sub prep {
  # Connect to the cache.
  # Why are we doing this cache business?
  # It takes a long time to validate 'completeness' for a spool,
  # so much time that we want to remember it from run to run.
  # We started by saving state to a flat file, but we quickly needed
  # to save more complicated data, run count, time of check, completeness.
  # This turned into a "hash of hashes".  Flat file was no longer appropriate.
  # Perl tie can't handle a hash of hashes, but MLDBM tie advertises that it
  # can, but it had significant bugs that made it unreliable.  SQLite is
  # a fast and easy way for us to keep state over a long run.
  # Note we don't care much about normalized table forms.  Just save the data.
  my $self = shift;
  my $cachefile = $self->{parent}->{cachefile};

  $self->local_debug("prep()\n");

  if (-f $cachefile) {
    $self->logger("using existing cache $cachefile\n");
  } else {
    open(DB,">$cachefile") or
      $self->error("failed to create new cache $cachefile: $!\n");
    close(DB);
    $self->logger("creating new cache $cachefile\n");
  }

  my $connected = 0;
  my $retries = 0;
  my $max_retries = $self->{parent}->{config}->{db_tries};
  my $dsn = "DBI:SQLite:dbname=$cachefile";

  while (!$connected and $retries < $max_retries) {

    $self->logger("SQLite trying to connect: $retries: $cachefile\n");

    try eval {
      $self->{dbh} = DBI->connect( $dsn,"","",
          {
            PrintError => 0,
            AutoCommit => 1,
            RaiseError => 1,
          }
        ) or $self->error("couldn't connect to database: " . $self->{dbh}->errstr);
      $connected = 1;
    };

    if ( catch my $err ) {
      $retries += 1;
      $self->logger("SQLite can't connect, retrying: $cachefile: $!\n");
      sleep(1);
    };

  }

  $self->error("SQLite can't connect after $max_retries tries, giving up\n")
    if (!$connected);

  $self->local_debug("Connected to: $cachefile\n");

  # NOTE: review the DB table format, what might be better?
  # Repeatedly considered storing JOBID, but a row keyed on spoolname only has one field
  # JOBID but may have N jobs related to FILES.
  my $sql = "CREATE TABLE IF NOT EXISTS spools (spoolname VARCHAR PRIMARY KEY, time VARCHAR(255), count INTEGER UNSIGNED NOT NULL DEFAULT 0, complete SMALL NOT NULL DEFAULT 0, files VARCHAR)";

  return $self->sql_exec($sql);
}

sub add {
  # Update cache, note insert or update.

  my $self = shift;
  my $spoolname = shift;
  my $key = shift;
  my $value = shift;
  my $sql;

  $self->local_debug("add($spoolname,$key,$value)\n");

  $sql = "SELECT COUNT(*) FROM spools where spoolname = ?";
  my @result = $self->sql_exec($sql,($spoolname));

  if ( $result[0] == 0 ) {
    $sql = "INSERT INTO spools
            ($key,spoolname)
            VALUES (?,?)";
  } else {
    $sql = "UPDATE spools
            SET $key = ?
            WHERE spoolname = ?";
  }

  return $self->sql_exec($sql,($value,$spoolname));
}

sub del {
  # Set a cache value to blank.
  # Currently only used for 'files' field.
  my $self = shift;
  my $spoolname = shift;
  my $key = shift;

  $self->local_debug("del($spoolname,$key)\n");
  my $sql = "UPDATE spools SET $key = '' WHERE spoolname = ?";
  return $self->sql_exec($sql,($spoolname));
}

sub counter {
  # Increment the 'counter' field.
  my $self = shift;
  my $spoolname = shift;
  $self->local_debug("counter($spoolname)\n");

  my $sql = "UPDATE spools SET count=count+1 WHERE spoolname=?";
  return $self->sql_exec($sql,($spoolname))
}

sub fetch_complete {
  # The 'complete' field is special in that we sometimes want
  # to know 'complete' across all spools, not for one spool.
  my $self = shift;
  my $value = shift;
  $self->local_debug("fetch_complete($value)\n");
  my $sql = "SELECT spoolname FROM spools WHERE complete = ?";
  return $self->sql_exec($sql,($value));
}

sub count {
  my $self = shift;
  my $spoolname = shift;
  $self->local_debug("count($spoolname)\n");
  my $sql = "SELECT count(*) FROM spools WHERE spoolname = ?";
  return $self->sql_exec($sql,($spoolname));
}

sub fetch {
  # Fetch an item from the cache.
  my $self = shift;
  my $spoolname = shift;
  my $key = shift;
  my $value = shift;
  my $sql;
  $self->local_debug("fetch($spoolname,$key)\n");

  if (defined $value) {
    $sql = "SELECT * FROM spools WHERE spoolname = ? AND $key = ?";
    return $self->sql_exec($sql,($spoolname,$value));
  } else {
    $sql = "SELECT $key FROM spools WHERE spoolname = ?";
    return $self->sql_exec($sql,($spoolname));
  }
}

1;

__END__

=pod

=head1 NAME

Genome::Model::Tools::LSFSpool::Cache - A class representing an LSF Spool Cache.

=head1 SYNOPSIS

  use Genome::Model::Tools::LSFSpool::Cache
  my $suite = create Genome::Model::Tools::LSFSpool::Cache

=head1 DESCRIPTION

This simple caching mechanism implements an SQLite database to save the
progress of an LSF Spool.

=head1 CLASS METHODS

=over

=item create()

Instantiates the class.

=item logger()

Cache class' logger().

=item local_debug()

Cache class' debugging.

=item sql_exec()

Execute an SQL statement.

=item prep()

Prepare the database, creating tables if not already present.

=item add()

Add an item to the cache using INSERT or UPDATE.

=item del()

Delete an item from the cache.

=item counter()

Increment the 'count' field.

=item fetch_complete()

Fetch all spools with a specified value of 'complete'.

=item count()

Execute a COUNT.

=item fetch()

Fetch an item from the cache.

=back

=head1 AUTHOR

Matthew Callaway (mcallawa@genome.wustl.edu)

=head1 COPYRIGHT

Copyright (c) 2010, Washington University Genome Center.  All Rights Reserved.

This module is free software. It may be used, redistributed and/or modified
under the terms of the Perl Artistic License (see
http://www.perl.com/perl/misc/Artistic.html)

=cut
