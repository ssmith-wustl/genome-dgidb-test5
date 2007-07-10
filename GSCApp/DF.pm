package GSCApp::DF;

use warnings;
use strict;

our $ERROR_MESSAGE;

sub disk_usage_file {

    if ($^O eq 'MSWin32') {
        return q(\\\\winsvr.gsc.wustl.edu\gsc\var\cache\disk-usage\df.out);
    } else {
        return q(/gsc/var/cache/disk-usage/df.out);
    }
}

sub get_disk_lines {

    my ($class) = @_;
    $ERROR_MESSAGE = undef;

    my $disk_usage_file=$class->disk_usage_file;
    my $fh=new IO::File("< $disk_usage_file");

    if ($fh) {
        my @disk_lines = $fh->getlines();
        return \@disk_lines;
    }

    $ERROR_MESSAGE = "Unable to open $disk_usage_file";
    return;
}


sub get_disks_for_group {

    my ($class, $group_pattern) = @_;

    return GSCApp::DF->get_disks_for(group => $group_pattern);
}

sub get_disks_for_vol {
    my ($class, $vol) = @_;

    return GSCApp::DF->get_disks_for(vol => $vol);
}

sub get_disks_for {

    my ($class, $key, $pattern) = @_;
    my @disks;

    my $disk_lines = GSCApp::DF->get_disk_lines();

    for my $disk_line (@$disk_lines) {
        chomp $disk_line;
        
        #Ignore the first line, which starts with a #
        next if($disk_line=~/^\#/);

        my ($location_line,
            $total,
            $used,
            $avail,
            $percent_capacity,
            $mount,
            $group)=split(/\s+/, $disk_line);
        my ($vol,
            $host,
            $fs)=split(/:/, $location_line);

        $percent_capacity =~ s/\D//g if $percent_capacity;
        
        my $disk=GSCApp::DF::disk->new(vol              => $vol,
                                       host             => $host,
                                       fs               => $fs,
                                       total            => $total,
                                       used             => $used,
                                       avail            => $avail,
                                       percent_capacity => $percent_capacity,
                                       mount            => $mount,
                                       group            => $group,
        );
        ###########################################################

        push @disks, $disk if($disk->{$key}=~/$pattern/);
    }

    return(@disks);
}


1;

package GSCApp::DF::disk;

use strict;
use warnings;
use base 'App::Accessor';

__PACKAGE__->accessorize(qw(
                            vol
                            host
                            fs 
                            total
                            used
                            avail
                            percent_capacity 
                            mount
                            group
                            )
                         );

sub new {
    my $class=shift;
    my %params=@_;

    my $self={%params};
    bless $self, $class;

    return $self;
}

1;
