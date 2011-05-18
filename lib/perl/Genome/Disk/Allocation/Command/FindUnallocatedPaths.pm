package Genome::Disk::Allocation::Command::FindUnallocatedPaths;

use warnings;
use strict;

use Genome;
use IO::Dir;

class Genome::Disk::Allocation::Command::FindUnallocatedPaths{
    is => 'Command::V2',
    has_input => [
        disk_volume => {
            is => 'Genome::Disk::Volume',
            doc => 'Identifier for disk volume on which to find unallocated paths.',
        },
    ],
    has_optional => [
        _allocated_paths => {
            is => 'ArrayRef',
        },
        _unallocated_paths => {
            is => 'Text',
            is_many => 1,
            is_output => 1,
        },
    ]
};

sub execute{

    my $self = shift;
    my $mount_path = $self->disk_volume->mount_path;
    my @allocations = Genome::Disk::Allocation->get(mount_path=>$mount_path);
    unless(@allocations) {
        $self->warning_message("No allocations on $mount_path.");
        return;
    }
    my @allocated_paths;
    for my $allocation (@allocations) {
        push @allocated_paths, $allocation->absolute_path;
    }
    $self->_allocated_paths(\@allocated_paths);
    $DB::single=1;
    my ($allocated_subpaths, @unallocated_paths) = $self->find_unallocated_paths($mount_path);
    print join("\n", @unallocated_paths);
    $self->_unallocated_paths(\@unallocated_paths);
    return 1;
}

sub find_unallocated_paths{

    my ($self, $path) = @_;
    my $relevant = 0;
    my @unallocated_children;
    my $has_allocated_children = 0;
    my $allocated_paths_ref = $self->_allocated_paths;
    foreach my $allocation (@$allocated_paths_ref){
        if($path eq $allocation){
            return 1;
        }
    }
    foreach my $allocation (@$allocated_paths_ref){
        if($allocation =~ /^\Q$path/){
            $relevant = 1;
        }
    }
    unless($relevant){
        return 0, $path
    }
 
    if (-l $path){
        return 0, $path;
    }
    if (-d $path){
        my $dh = IO::Dir->new($path);
        unless($dh){
            die $self->error_message("Could not open directory handle for $path.");
        }
        while(my $subpath = $dh->read()){
            next if $subpath =~ /^\.\.?$/;
            my ($allocated_subpaths, @unallocated_subpaths) = $self->find_unallocated_paths("$path/$subpath");
            if($allocated_subpaths) {
                $has_allocated_children = 1;
            }
            @unallocated_children = (@unallocated_children, @unallocated_subpaths);
        }
        if($has_allocated_children) {
            return 1, @unallocated_children;
        }else{
            return 0, "$path/";
        }
    }else{
        return 0, $path;
    }
}
