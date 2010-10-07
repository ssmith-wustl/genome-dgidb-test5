package Genome::ProcessingProfile::Benchmark;

use strict;
use warnings;
use Genome;

class Genome::ProcessingProfile::Benchmark {
    is => 'Genome::ProcessingProfile',
    has => [
        server_dispatch => {
            is_constant => 1,
            is_class_wide => 1,
            # If value is not specified, or not 'inline', will default to 'workflow' queue
            value => 'inline',
            doc => 'lsf queue to submit the launcher or \'inline\''
        },
        job_dispatch => {
            is_constant => 1,
            is_class_wide => 1,
            # This is a queue name, but 'inline' is reserved for run on local machine.
            value => 'inline',
            doc => 'lsf queue to submit jobs or \'inline\' to run them in the launcher'
        }
    ],
    has_param => [
        command => {
            doc => 'command to benchmark',
        },
        args => {
            is_optional => 1,
            doc => 'the arguments to use',
        }
    ],
    doc => "benchmark profile captures statistics after command execution"
};

sub _initialize_model {
    my ($self,$model) = @_;
    $self->status_message("defining new model " . $model->__display_name__ . " for profile " . $self->__display_name__);
    return 1;
}

sub _initialize_build {
    my ($self,$build) = @_;
    $self->status_message("defining new build " . $build->__display_name__ . " for profile " . $self->__display_name__);
    return 1;
}

sub _system_snapshot {
    # FIXME: Make these stubs and subclass when we get closer to finished
    my $self = shift;
    my $dir = shift;

    # We create a cache file for this build
    my $cache = "$dir/systemp_snapshot.cache";
    return if (! defined $dir);

    my $s = snapshot->new($cache);
    return $s->run();
}

sub _set_metrics {
    # Stub to be overridden in a Benchmark subclass
    my ($self,$build,$metrics) = @_;
    foreach my $key (keys %$metrics) {
        $build->set_metric($key,$metrics->{$key});
    }
}

sub _execute_build {
    my ($self,$build) = @_;
    $self->status_message("executing build logic for " . $self->__display_name__ . ':' .  $build->__display_name__);

    # combine params with build inputs and produce output in the build's data directory

    $DB::single=1;

    my $cmd = $self->command;
    my $args = $self->args || '';

#    my @inputs = $build->inputs();

    my $dir = $build->data_directory;

    $self->_system_snapshot($dir);

    my $exit_code = system "$cmd $args >$dir/output 2>$dir/errors";
    $exit_code = $exit_code >> 8;
    if ($exit_code != 0) {
        $self->error_message("Failed to run $cmd with args $args!  Exit code: $exit_code.");
        return;
    }

    my $metrics = $self->_system_snapshot($dir);
    $self->_set_metrics($build,$metrics);

    return 1;
}

sub _validate_build {
    my $self = shift;
    my $dir = $self->data_directory;

    my @errors;
    unless (-e "$dir/output") {
        my $e = $self->error_message("No output file $dir/output found!");
        push @errors, $e;
    }
    unless (-e "$dir/errors") {
        my $e = $self->error_message("No output file $dir/errors found!");
        push @errors, $e;
    }

    if (@errors) {
        return;
    }
    else {
        return 1;
    }
}

#1;

package snapshot;

use Storable;
use Data::Dumper;

use strict;
use warnings;

sub new {
  my $class = shift;
  my $cachepath = shift;
  my $self = {
    'cpu' => '/proc/stat',
    'net' => '/proc/net/dev',
    'output' => 'snapshot.cache',
  };
  if (defined $cachepath) {
    $self->{output} = $cachepath;
  }
  bless $self, $class;
  return $self;
}

sub read_net {
  my $self = shift;
  my $this = shift;

  # Read network data for each interface and add it to our
  # data structure.
  my $netfh = Genome::Utility::FileSystem->open_file_for_reading($self->{net});
  unless($netfh){
    $self->status_message("Could not open file $self->{net} for reading.");
    return;
  }
  while (<$netfh>) {
    chomp;
    next unless (/:/);
    my $line = $_;
    my $i = {};

    my $idx = index($line,":");
    my $iface = substr($line,0,$idx);
    $iface =~ s/\s+//g; # trim all whitespac
    $line = substr($line,$idx+1);
    $line =~ s/^\s+//; # trim leading whitespace

    my ($rbytes,$rpackets,$rerrs,$rdrop,$rfifo,$rframe,$rcompressed,$rmulticast, $tbytes,$tpackets,$terrs,$tdrop,$tfifo,$tcalls,$tcarrier,$tcompressed) = split(/\s+/,$line);

    $i = {
      'rbytes' => $rbytes,
      'rpackets' => $rpackets,
      'rerrs' => $rerrs,
      'rdrop' => $rdrop,
      'rfifo' => $rfifo,
      'rframe' => $rframe,
      'rcompressed' => $rcompressed,
      'rmulticast' => $rmulticast,
      'tbytes' => $tbytes,
      'tpackets' => $tpackets,
      'terrs' => $terrs,
      'tdrop' => $tdrop,
      'tfifo' => $tfifo,
      'tcalls' => $tcalls,
      'tcarrier' => $tcarrier,
      'tcompressed' => $tcompressed,
    };
    $$this->{'interfaces'}->{$iface} = $i;
  }
  close($netfh);
}

sub read_cpu {
  my $self = shift;
  my $this = shift;

  # Read cpu data and add it to our data structure.
  # FIXME: should not be fatal to build
  my $cpufh = Genome::Utility::FileSystem->open_file_for_reading($self->{cpu});
  unless($cpufh){
    $self->status_message("Could not open file $self->{cpu} for reading.");
    return;
  }
  my $c = <$cpufh>;
  close($cpufh);
  chomp $c;

  my ($label,$user,$nice,$system,$idle,$iowait,$irq,$softirq) = split(/\s+/,$c);
  $$this = {
    'walltime' => time(),
    'user' => $user,
    'nice' => $nice,
    'system' => $system,
    'idle' => $idle,
    'iowait' => $iowait,
    'irq' => $irq,
    'softirq' => $softirq,
  };
}

sub save {
  my $self = shift;
  my $result = shift;
  Storable::nstore($result,$self->{output});
}

sub get {
  my $self = shift;
  return Storable::retrieve($self->{output});
}

sub compare {
  my $self = shift;
  my $last = shift;
  my $this = shift;
  return if (! scalar keys %$last);
  # Compare this run with last run.
  foreach my $key (keys %{$$this}) {
    my $diff;
    if (ref($$this->{$key})) {
      # This is a ref, and thus the interfaces reference
      foreach my $iface (keys %{ $$this->{$key} } ) {
        foreach my $item (keys %{ $$this->{$key}->{$iface} } ) {
          my $a = $last->{'interfaces'}->{$iface}->{$item};
          my $b = $$this->{'interfaces'}->{$iface}->{$item};
          $self->error("fatal: field is not numeric: $a")
            if ($a !~ /\d+/);
          $self->error("fatal: field is not numeric: $b")
            if ($b !~ /\d+/);
          #next if ($a !~ /\d+/ or $b !~ /\d+/);
          $diff = $b - $a;
          $$this->{'interfaces'}->{$iface}->{"d_" . $item} = $diff;
        }
      }
    } else {
      $diff = $$this->{$key} - $last->{$key};
      $$this->{"d_" . $key} = $diff;
    }
  }
}

sub report {
  # The functions above get more data than we care to see.
  # This function selects just things we care about.
  my $self = shift;
  my $result = shift;
  my $metrics = {};

  # Display CPU deltas
  foreach my $item ('d_idle', 'd_iowait', 'd_irq', 'd_nice', 'd_softirq', 'd_system', 'd_user', 'd_walltime' ) {
    my $name = $item;
    $name =~ s/^d_//;
    $metrics->{$name} = $result->{$item} if (exists $result->{$item});
  }

  # Display only eth0 items, convert to bits
  my $iface = "eth0";
  foreach my $item ('d_rbytes','d_tbytes') {
    my $name = $item;
    $name =~ s/^d_//;
    $metrics->{$name} = int($result->{interfaces}->{$iface}->{$item}) * 8
      if (exists $result->{interfaces}->{$iface}->{$item});
  }
  foreach my $item ('d_rpackets','d_tpackets') {
    my $name = $item;
    $name =~ s/^d_//;
    #print "$name=" . $result->{interfaces}->{$iface}->{$item} . "\n"
    $metrics->{$name} = $result->{interfaces}->{$iface}->{$item}
      if (exists $result->{interfaces}->{$iface}->{$item});
  }
  return $metrics;
}

sub display {
  my $self = shift;
  my $result = shift;

  # Cheap dump:
  $Data::Dumper::Sortkeys = 1;
  print Dumper($result);
  return;

  # Slightly less cheap dump, basically sorts.
  print "cpu\n";
  foreach my $key (sort keys %$result) {
    next if ($key =~ /interfaces/);
    print "$key $result->{$key}\n";
  }
  print "\nnetwork\n";
  foreach my $iface (sort keys %{ $result->{'interfaces'} }) {
    print "$iface\n";
    foreach my $key (sort keys %{ $result->{'interfaces'}->{$iface} }) {
      print "$key $result->{'interfaces'}->{$iface}->{$key}\n";
    }
    print "\n";
  }
}

sub run {
  my $self = shift;
  my $last = {};
  my $this = {};
  if (-f $self->{output}) {
    $last = $self->get();
  }
  $self->read_cpu(\$this);
  $self->read_net(\$this);
  if ($last != {}) {
    $self->compare($last,\$this);
  }
  $self->save($this);
  my $metrics;
  if ($this and $last) {
    $metrics = $self->report($this);
  }
  return $metrics;
}

1;
