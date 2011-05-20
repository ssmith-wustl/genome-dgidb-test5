package Genome::Disk::Group::Command::FindUnallocatedPaths;

use warnings;
use strict;

use Genome;

class Genome::Disk::Group::Command::FindUnallocatedPaths{
    is => 'Command::V2',
    has_input => [
        group => {
            is => 'Genome::Disk::Group',
            doc => 'Identifier for group on which to find unallocated paths.',
        },
    ],
    has_optional => [
        _unallocated_paths => {
            is => 'Text',
            is_many => 1,
            is_output => 1,
        },
    ]
};

sub execute{
    my $self = shift;
    for my $volume ($self->group->volumes) {
        #we only care for active drives
        unless($volume->disk_status eq 'active') {
            next;
        }
        #and drives whene we might allocate files
        unless($volume->can_allocate){
            next;
        }
        $DB::single = 1;
        #my $cmd = Genome::Disk::Allocation::Command::FindUnallocatedPaths->create(
        #    disk_volume => $volume,
        #);
        #$cmd->execute;
        #my @paths = $self->_unallocated_paths(), $cmd->_unallocated_paths();
        #$self->_unallocated_paths(\@paths);
        my $cmd = "genome disk allocation find-unallocated-paths --disk-volume mount_path=" . $volume->mount_path;
        my $path = $volume->mount_path;
        $path =~ s/\/gscmnt\///;
        system("bsub -u swallace\@genome.wustl.edu -J find-unallocated-$path -eo /gscuser/swallace/unallocated-paths/$path.err -oo /gscuser/swallace/unallocated-paths/$path.out $cmd\n");
    }
}
