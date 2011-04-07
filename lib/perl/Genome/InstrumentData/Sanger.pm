# bdericks: Need to refactor out dependencies on GSC and App

package Genome::InstrumentData::Sanger;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Sanger {
    is => 'Genome::InstrumentData',
    has_constant => [
        sequencing_platform => { value => 'sanger' },
    ],
    has_optional => [
        research_project => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'research_project' ],
            is_mutable => 1,
            default_value => 'unknown',
        },
        disk_allocation => {
            is => 'Genome::Disk::Allocation',
            calculate_from => [ 'subclass_name', 'id' ],
            calculate => q{ return Genome::Disk::Allocation->get(owner_id => $id, owner_class_name => $subclass_name); },
        },
        # TODO Need to refactor this away
        _gsc_run => {
            is => 'GSC::Run',
            calculate_from => [qw/ id /],
            calculate => q| GSC::Run->get($id); |,
            doc => 'GSC Run from LIMS',
        },
    ],
};

sub full_path {
    my $self = shift;

    # FIXME Legacy that would dump data to unallocated space. Need to get
    #  list of full_paths from the db, then rm from db, then rm from
    #  file system. Then dump to file system will put them on allocated
    #  space.
    #  1 - disk allocation
    #  2 - full path from attributes
    my $disk_allocation = $self->disk_allocation;
    if ( $disk_allocation ) {
        return $disk_allocation->absolute_path;
    }

    return $self->_full_path;
}

sub _full_path {
    my $self = shift;

    my ($full_path_attr) = grep { $_->attribute_label eq 'full_path' } $self->attributes;
    return unless $full_path_attr;
    
    my $full_path = $full_path_attr->attribute_value;
    return $full_path if -d $full_path;
    
    return;
}

sub resolve_full_path {
    return full_path(@_);
}

sub dump_to_file_system {
    my $self = shift;

    my $disk_allocation = $self->disk_allocation;
    unless ( $disk_allocation ) {
        $disk_allocation = Genome::Disk::Allocation->allocate(
            disk_group_name => 'info_alignments',
            allocation_path => '/instrument_data/sanger'.$self->id,
            kilobytes_requested => 10240, # 10 Mb
            owner_class_name => $self->class,
            owner_id => $self->id
        );
        unless ($disk_allocation) {
            die $self->error_message('Failed to create disk allocation for sanger instrument data '.$self->id);
        }
    }

    my $data_dir = $disk_allocation->absolute_path;
    unless ( Genome::Sys->validate_existing_directory($data_dir) ) {
        die $self->error_message('Absolute path from disk allocation does not exist for sanger instrument data '.$self->id);
    }

    my $read_cnt = 0;
    my $reads = $self->_get_read_iterator
        or return;

    while ( my $read = $reads->next ) {
        $read_cnt++;
        my $scf_name = $read->default_file_name('scf');
        my $scf_file = sprintf('%s/%s.gz', $data_dir, $scf_name);
        my $size = -s $scf_file;
        next if $size and $size > 1000; # if small retry dump
        unlink $scf_file if -e $scf_file; 
        my $scf_fh = IO::File->new($scf_file, 'w');
        unless ( $scf_fh ) {
            $self->error_message("Can't open scf ($scf_file)\n$!");
            return;
        }
        $scf_fh->print( Compress::Zlib::memGzip($read->scf_content) );
        $scf_fh->close;
        $self->error_message("No scf content for $scf_name") unless -s $scf_file;
    }

    unless ( $read_cnt ) {
        $self->error_message( sprintf("No reads found for run (%s)", $self->run_name) );
        return;
    }

    return 1;
}

sub _get_read_iterator {
    my $self = shift;
    my $reads = App::DB::TableRow::Iterator->new(
        class => 'GSC::Sequence::Read',
        params => {
            prep_group_id => $self->run_name,
        },
    );

    unless ( $reads ) {
        $self->error_message( sprintf('Could not make read iterartor for run name (%s)', $self->run_name) );
        return;
    }

    return $reads;
}

1;
